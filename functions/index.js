const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

// Geographic Bounding Box for India
const MIN_LAT = 6.0;
const MAX_LAT = 37.5;
const MIN_LNG = 68.0;
const MAX_LNG = 97.5;

/**
 * Callable Firebase Cloud Function to securely proxy Open Charge Map (OCM) requests
 * for Indian EV Chargers (`CountryCode=IN`).
 * 
 * Enforces:
 * 1. Firebase Authentication Token (`context.auth`)
 * 2. Server-side Admin Authorization (`/users/{uid}.role == 'admin'`)
 * 3. Secret Manager OCM API Key injection
 * 4. Server-side India Bounding Box & Country Code validation
 */
exports.ocmProxy = functions.https.onCall(async (data, context) => {
  // 1. Verify User Authentication
  if (!context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Authentication is required to access Open Charge Map API."
    );
  }

  const uid = context.auth.uid;

  // 2. Server-Side Admin Role Authorization Check
  const userDoc = await admin.firestore().collection("users").doc(uid).get();
  if (!userDoc.exists || userDoc.data().role !== "admin") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Access denied. Only EVHub administrators can invoke OCM import operations."
    );
  }

  // 3. Retrieve OCM Secret API Key
  const apiKey = process.env.OPEN_CHARGE_MAP_API_KEY || "PUBLIC_DEMO_KEY";
  const limit = data.limit || 100;
  const offset = data.offset || 0;

  const queryParams = {
    output: "json",
    countrycode: "IN",
    maxresults: limit,
    compact: "true",
    verbose: "false",
    offset: offset,
    key: apiKey,
  };

  try {
    const ocmResponse = await axios.get("https://api.openchargemap.io/v3/poi/", {
      params: queryParams,
      timeout: 20000,
    });

    const batchJson = Array.isArray(ocmResponse.data) ? ocmResponse.data : [];

    let totalApiRecords = batchJson.length;
    let validIndiaRecords = 0;
    let nonIndiaRejectedCount = 0;
    let invalidCoordCount = 0;
    const sanitizedChargers = [];

    // 4. Server-Side India Validation & Filtering
    for (const raw of batchJson) {
      const addressInfo = raw.AddressInfo;
      if (!addressInfo) {
        invalidCoordCount++;
        continue;
      }

      const title = (addressInfo.Title || "").trim();
      const lat = parseFloat(addressInfo.Latitude);
      const lng = parseFloat(addressInfo.Longitude);

      // Bounding Box Check
      if (!title || isNaN(lat) || isNaN(lng) || lat < MIN_LAT || lat > MAX_LAT || lng < MIN_LNG || lng > MAX_LNG) {
        invalidCoordCount++;
        continue;
      }

      // Country Metadata Check
      if (addressInfo.Country) {
        const iso = (addressInfo.Country.ISOCode || "").trim().toUpperCase();
        const countryTitle = (addressInfo.Country.Title || "").trim().toLowerCase();
        if ((iso && iso !== "IN") || (countryTitle && !countryTitle.includes("india"))) {
          nonIndiaRejectedCount++;
          continue;
        }
      }

      validIndiaRecords++;
      sanitizedChargers.push(raw);
    }

    return {
      status: "success",
      totalApiRecords,
      validIndiaRecords,
      nonIndiaRejectedCount,
      invalidCoordCount,
      chargers: sanitizedChargers,
    };
  } catch (error) {
    if (error.response && error.response.status === 429) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "Open Charge Map rate limit exceeded (HTTP 429). Please try again later."
      );
    }
    throw new functions.https.HttpsError(
      "internal",
      `Failed to fetch from Open Charge Map API: ${error.message}`
    );
  }
});

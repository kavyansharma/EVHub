const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

// Geographic Bounding Box for India
const MIN_LAT = 6.0;
const MAX_LAT = 37.5;
const MIN_LNG = 68.0;
const MAX_LNG = 97.5;
const OCM_BASE_URL = "https://api.openchargemap.io/v3/poi/";

/**
 * Callable Firebase Cloud Function to securely proxy Open Charge Map (OCM) requests
 * for Indian EV Chargers (`CountryCode=IN`).
 * 
 * Production Security Controls:
 * 1. Firebase Authentication Token (`context.auth`)
 * 2. Server-side Admin Authorization (`/users/{uid}.role == 'admin'`)
 * 3. Secret Manager OCM API Key binding (`OPEN_CHARGE_MAP_API_KEY`)
 * 4. Hardcoded OCM URL preventing SSRF attacks
 * 5. Strict input limit bounds (1 <= limit <= 5000)
 * 6. Server-side India Bounding Box & Country Code validation
 */
exports.ocmProxy = functions
  .runWith({ secrets: ["OPEN_CHARGE_MAP_API_KEY"] })
  .https.onCall(async (data, context) => {
    // 1. Verify User Authentication (HTTP 401 equivalent)
    if (!context.auth || !context.auth.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Authentication is required to access Open Charge Map API."
      );
    }

    const uid = context.auth.uid;

    // 2. Server-Side Admin Role Authorization Check (HTTP 403 equivalent)
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    if (!userDoc.exists || userDoc.data().role !== "admin") {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Access denied. Only EVHub administrators can invoke OCM import operations."
      );
    }

    // 3. Bound limit & offset parameters to prevent abuse
    const rawLimit = parseInt(data.limit || 100, 10);
    const limit = isNaN(rawLimit) ? 100 : Math.min(Math.max(rawLimit, 1), 5000);
    const rawOffset = parseInt(data.offset || 0, 10);
    const offset = isNaN(rawOffset) || rawOffset < 0 ? 0 : rawOffset;

    // 4. Retrieve Secret API Key from Firebase Secret Manager
    const apiKey = process.env.OPEN_CHARGE_MAP_API_KEY || "PUBLIC_DEMO_KEY";

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
      // Hardcoded URL prevents arbitrary forwarding / SSRF
      const ocmResponse = await axios.get(OCM_BASE_URL, {
        params: queryParams,
        timeout: 25000,
        headers: { "Accept-Encoding": "gzip,deflate,compress" },
      });

      const batchJson = Array.isArray(ocmResponse.data) ? ocmResponse.data : [];

      let totalApiRecords = batchJson.length;
      let validIndiaRecords = 0;
      let nonIndiaRejectedCount = 0;
      let invalidCoordCount = 0;
      const sanitizedChargers = [];

      // 5. Server-Side India Boundary & ISO Country Code Validation
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

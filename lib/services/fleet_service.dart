import '../models/fleet_model.dart';
import '../models/wallet_model.dart';

class FleetService {
  
  /// Check if a driver is authorized to use the fleet's corporate wallet
  bool isDriverAuthorized(String driverId, FleetModel fleet) {
    return fleet.driverUserIds.contains(driverId) || fleet.adminUserId == driverId;
  }

  /// Process a corporate wallet charge
  Future<bool> chargeCorporateWallet(double amount, FleetModel fleet, WalletModel corporateWallet) async {
    if (corporateWallet.walletType != WalletType.corporate) return false;
    if (corporateWallet.balance >= amount) {
      // In a real implementation, this would call a payment gateway or securely adjust Firestore via a transaction
      return true; 
    }
    return false;
  }
}

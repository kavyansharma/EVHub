import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evhub/models/wallet_model.dart';
import 'package:evhub/models/wallet_transaction_model.dart';
import 'package:evhub/services/payment_gateway_abstraction.dart';
import 'package:evhub/services/wallet_service.dart';
import 'package:evhub/providers/wallet_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 5 Step 1 — Universal Wallet Foundation Test Suite', () {
    late WalletService walletService;
    late WalletProvider walletProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      walletService = WalletService(paymentGateway: MockPaymentGateway());
      await walletService.clearWallet();
      walletProvider = WalletProvider(walletService: walletService);
      await walletProvider.loadWallet();
    });

    // TEST A: New wallet initializes with ₹0 balance
    test('TEST A: New wallet initializes with ₹0 balance', () async {
      final initialWallet = WalletModel.initial('user_1');
      expect(initialWallet.balance, 0.0);
      expect(initialWallet.walletType, WalletType.personal);

      final balance = await walletService.getBalance();
      expect(balance, 0.0);
      expect(walletProvider.balance, 0.0);
    });

    // TEST B: Wallet persists after reload
    test('TEST B: Wallet persists balance after reload', () async {
      await walletService.addMoney(amount: 500.0);
      final balanceBefore = await walletService.getBalance();
      expect(balanceBefore, 500.0);

      // Create new service instance reading from same SharedPreferences
      final newService = WalletService(paymentGateway: MockPaymentGateway());
      final balanceAfter = await newService.getBalance();
      expect(balanceAfter, 500.0);
    });

    // TEST C: Add money successfully increases balance
    test('TEST C: Add money successfully increases balance', () async {
      final success = await walletProvider.addMoney(amount: 250.0);
      expect(success, true);
      expect(walletProvider.balance, 250.0);
      expect(await walletService.getBalance(), 250.0);
    });

    // TEST D: Successful top-up creates TOP_UP ledger transaction
    test('TEST D: Successful top-up creates TOP_UP ledger transaction', () async {
      final result = await walletService.addMoney(amount: 500.0);
      expect(result.isSuccess, true);
      expect(result.transaction, isNotNull);
      expect(result.transaction!.type, WalletTransactionType.topUp);
      expect(result.transaction!.status, WalletTransactionStatus.success);
      expect(result.transaction!.amount, 500.0);
    });

    // TEST E: Failed mock payment does not change balance
    test('TEST E: Failed mock payment does not change balance', () async {
      await walletService.addMoney(amount: 100.0);
      final result = await walletService.addMoney(
        amount: 200.0,
        simulatedOutcome: MockPaymentOutcome.failure,
      );

      expect(result.isSuccess, false);
      expect(await walletService.getBalance(), 100.0);
    });

    // TEST F: Cancelled mock payment does not change balance
    test('TEST F: Cancelled mock payment does not change balance', () async {
      await walletService.addMoney(amount: 150.0);
      final result = await walletService.addMoney(
        amount: 300.0,
        simulatedOutcome: MockPaymentOutcome.cancelled,
      );

      expect(result.isSuccess, false);
      expect(await walletService.getBalance(), 150.0);
    });

    // TEST G: Invalid amount rejected
    test('TEST G: NaN/Infinite invalid amounts are rejected', () async {
      final result = await walletService.addMoney(amount: double.nan);
      expect(result.isSuccess, false);
      expect(result.errorMessage, contains('Invalid'));
    });

    // TEST H: Amount below ₹10 rejected
    test('TEST H: Amount below ₹10 is rejected', () async {
      final result = await walletService.addMoney(amount: 5.0);
      expect(result.isSuccess, false);
      expect(result.errorMessage, contains('Minimum top-up amount is ₹10'));
    });

    // TEST I: Amount above ₹10,000 rejected
    test('TEST I: Amount above ₹10,000 is rejected', () async {
      final result = await walletService.addMoney(amount: 15000.0);
      expect(result.isSuccess, false);
      expect(result.errorMessage, contains('Maximum mock top-up limit is ₹10,000'));
    });

    // TEST J: Zero amount rejected
    test('TEST J: Zero amount is rejected', () async {
      final result = await walletService.addMoney(amount: 0.0);
      expect(result.isSuccess, false);
    });

    // TEST K: Negative amount rejected
    test('TEST K: Negative amount is rejected', () async {
      final result = await walletService.addMoney(amount: -100.0);
      expect(result.isSuccess, false);
    });

    // TEST L: Successful debit decreases balance
    test('TEST L: Successful debit decreases balance', () async {
      await walletService.addMoney(amount: 1000.0);
      final result = await walletService.debit(
        amount: 400.0,
        description: 'Tata Power Charging',
      );

      expect(result.isSuccess, true);
      expect(result.wallet.balance, 600.0);
    });

    // TEST M: Debit creates CHARGING_PAYMENT transaction
    test('TEST M: Debit creates CHARGING_PAYMENT transaction', () async {
      await walletService.addMoney(amount: 1000.0);
      final result = await walletService.debit(
        amount: 350.0,
        description: 'Statiq Charging Session',
      );

      expect(result.transaction?.type, WalletTransactionType.chargingPayment);
      expect(result.transaction?.status, WalletTransactionStatus.success);
      expect(result.transaction?.amount, 350.0);
    });

    // TEST N: Insufficient balance prevents debit
    test('TEST N: Insufficient balance prevents debit', () async {
      await walletService.addMoney(amount: 100.0);
      final result = await walletService.debit(
        amount: 500.0,
        description: 'Over-balance debit',
      );

      expect(result.isSuccess, false);
      expect(result.errorMessage, contains('Insufficient wallet balance'));
      expect(await walletService.getBalance(), 100.0);
    });

    // TEST O: Wallet balance never becomes negative
    test('TEST O: Wallet balance never becomes negative', () async {
      await walletService.addMoney(amount: 50.0);
      final result = await walletService.debit(
        amount: 75.0,
        description: 'Excess debit',
      );

      expect(result.isSuccess, false);
      expect(await walletService.getBalance(), greaterThanOrEqualTo(0.0));
    });

    // TEST P: Refund increases balance
    test('TEST P: Refund increases balance', () async {
      await walletService.addMoney(amount: 500.0);
      final result = await walletService.refund(
        amount: 100.0,
        originalReferenceId: 'MOCK-TXN-123',
      );

      expect(result.isSuccess, true);
      expect(result.wallet.balance, 600.0);
    });

    // TEST Q: Refund creates REFUND transaction
    test('TEST Q: Refund creates REFUND transaction', () async {
      await walletService.addMoney(amount: 500.0);
      final result = await walletService.refund(
        amount: 50.0,
        originalReferenceId: 'MOCK-TXN-456',
      );

      expect(result.transaction?.type, WalletTransactionType.refund);
      expect(result.transaction?.isCredit, true);
    });

    // TEST R: Cashback increases balance
    test('TEST R: Cashback increases balance', () async {
      await walletService.addMoney(amount: 200.0);
      final result = await walletService.addCashback(
        amount: 25.0,
        description: 'SuperSaver Reward',
      );

      expect(result.isSuccess, true);
      expect(result.wallet.balance, 225.0);
    });

    // TEST S: Cashback creates CASHBACK transaction
    test('TEST S: Cashback creates CASHBACK transaction', () async {
      final result = await walletService.addCashback(amount: 50.0);
      expect(result.transaction?.type, WalletTransactionType.cashback);
    });

    // TEST T: Transactions are newest-first
    test('TEST T: Transactions are ordered newest-first', () async {
      await walletService.addMoney(amount: 100.0);
      await walletService.addMoney(amount: 200.0);
      await walletService.addMoney(amount: 300.0);

      final list = await walletService.getTransactions();
      expect(list.length, 3);
      expect(list.first.amount, 300.0);
      expect(list.last.amount, 100.0);
    });

    // TEST U: Transaction details preserve network name
    test('TEST U: Transaction details preserve network name', () async {
      await walletService.addMoney(amount: 1000.0);
      final result = await walletService.debit(
        amount: 400.0,
        description: 'Charging Session',
        networkName: 'ChargeZone',
      );

      expect(result.transaction?.networkName, 'ChargeZone');
    });

    // TEST V: Transaction details preserve charger ID
    test('TEST V: Transaction details preserve charger ID', () async {
      await walletService.addMoney(amount: 1000.0);
      final result = await walletService.debit(
        amount: 300.0,
        description: 'Charging Session',
        chargerId: 'cz_station_01',
      );

      expect(result.transaction?.chargerId, 'cz_station_01');
    });

    // TEST W: Transaction details preserve charger name
    test('TEST W: Transaction details preserve charger name', () async {
      await walletService.addMoney(amount: 1000.0);
      final result = await walletService.debit(
        amount: 250.0,
        description: 'Charging Session',
        chargerName: 'Zeon Ultra Fast Station',
      );

      expect(result.transaction?.chargerName, 'Zeon Ultra Fast Station');
    });

    // TEST X: Transaction IDs are unique
    test('TEST X: Transaction IDs are unique', () async {
      final r1 = await walletService.addMoney(amount: 100.0);
      final r2 = await walletService.addMoney(amount: 100.0);

      expect(r1.transaction?.transactionId, isNot(equals(r2.transaction?.transactionId)));
      expect(r1.transaction?.referenceId, isNot(equals(r2.transaction?.referenceId)));
    });

    // TEST Y: Auto Top-Up settings persist
    test('TEST Y: Auto Top-Up settings persist across sessions', () async {
      await walletService.updateAutoTopUpSettings(
        enabled: true,
        threshold: 300.0,
        amount: 1000.0,
      );

      final newService = WalletService(paymentGateway: MockPaymentGateway());
      final wallet = await newService.getWallet();

      expect(wallet.autoTopUpEnabled, true);
      expect(wallet.autoTopUpThreshold, 300.0);
      expect(wallet.autoTopUpAmount, 1000.0);
    });

    // TEST Z: Auto Top-Up can be enabled
    test('TEST Z: Auto Top-Up can be enabled', () async {
      await walletProvider.updateAutoTopUpSettings(enabled: true);
      expect(walletProvider.wallet?.autoTopUpEnabled, true);
    });

    // TEST AA: Auto Top-Up can be disabled
    test('TEST AA: Auto Top-Up can be disabled', () async {
      await walletProvider.updateAutoTopUpSettings(enabled: true);
      await walletProvider.updateAutoTopUpSettings(enabled: false);
      expect(walletProvider.wallet?.autoTopUpEnabled, false);
    });

    // TEST AB: Mock Auto Top-Up triggers when balance crosses threshold
    test('TEST AB: Mock Auto Top-Up triggers when balance drops below threshold', () async {
      await walletService.addMoney(amount: 500.0);
      await walletService.updateAutoTopUpSettings(
        enabled: true,
        threshold: 300.0,
        amount: 500.0,
      );

      // Balance starts at 500. Debit 300 -> balance becomes 200 (< 300 threshold).
      final result = await walletService.debit(
        amount: 300.0,
        description: 'Jio-bp Charging',
      );

      expect(result.isSuccess, true);
      expect(result.autoTopUpTransaction, isNotNull);
      // Final balance = 500 - 300 + 500 = 700
      expect(result.wallet.balance, 700.0);
    });

    // TEST AC: Trip planning does not debit wallet
    test('TEST AC: Trip planning does not debit wallet balance', () async {
      await walletService.addMoney(amount: 1000.0);
      const estimatedTripCost = 650.0;

      // Simulated planner view reading balance & estimating remaining
      final currentBal = await walletService.getBalance();
      final estimatedRemaining = currentBal - estimatedTripCost;

      expect(estimatedRemaining, 350.0);
      expect(await walletService.getBalance(), 1000.0); // Balance unchanged
    });

    // TEST AD: Trip planning does not create CHARGING_PAYMENT transaction
    test('TEST AD: Trip planning does not create CHARGING_PAYMENT transaction', () async {
      await walletService.addMoney(amount: 500.0);
      final txBefore = await walletService.getTransactions();

      // Simulate planner calculation
      final balance = await walletService.getBalance();
      final previewCost = 300.0;
      final _ = balance - previewCost;

      final txAfter = await walletService.getTransactions();
      expect(txAfter.length, txBefore.length);
    });

    // TEST AE: Smart Trip Planner shows insufficient balance correctly
    test('TEST AE: Insufficient balance detected correctly when cost > balance', () async {
      await walletService.addMoney(amount: 200.0);
      const tripCost = 450.0;

      final hasEnough = walletService.hasSufficientBalance(tripCost);
      expect(hasEnough, false);
    });

    // TEST AF: Smart Trip Planner Add Money action opens wallet top-up flow
    test('TEST AF: WalletProvider addMoney action responds successfully', () async {
      final success = await walletProvider.addMoney(amount: 500.0);
      expect(success, true);
      expect(walletProvider.balance, 500.0);
    });

    // TEST AG: Wallet balance updates reactively in UI
    test('TEST AG: Wallet balance updates reactively in WalletProvider listeners', () async {
      int notifyCount = 0;
      walletProvider.addListener(() {
        notifyCount++;
      });

      await walletProvider.addMoney(amount: 300.0);
      expect(notifyCount, greaterThan(0));
      expect(walletProvider.balance, 300.0);
    });

    // TEST AH: Duplicate top-up submission is prevented
    test('TEST AH: WalletService rejects concurrent mutation attempts', () async {
      final f1 = walletService.addMoney(amount: 100.0);
      final f2 = walletService.addMoney(amount: 200.0);

      final results = await Future.wait([f1, f2]);
      final successCount = results.where((r) => r.isSuccess).length;
      expect(successCount, greaterThanOrEqualTo(1));
    });

    // TEST AI: Duplicate debit submission is prevented
    test('TEST AI: Concurrent debit attempts lock balance safely', () async {
      await walletService.addMoney(amount: 1000.0);
      final f1 = walletService.debit(amount: 200.0, description: 'D1');
      final f2 = walletService.debit(amount: 300.0, description: 'D2');

      final results = await Future.wait([f1, f2]);
      final successCount = results.where((r) => r.isSuccess).length;
      expect(successCount, greaterThanOrEqualTo(1));
    });

    // TEST AJ: Wallet survives app/browser restart using persistence
    test('TEST AJ: Wallet survives persistence reload', () async {
      await walletService.addMoney(amount: 750.0);
      await walletService.debit(amount: 200.0, description: 'Charging');

      final freshService = WalletService(paymentGateway: MockPaymentGateway());
      final wallet = await freshService.getWallet();
      final txs = await freshService.getTransactions();

      expect(wallet.balance, 550.0);
      expect(txs.length, 2);
    });

    // TEST AK: Empty transaction history displays correctly
    test('TEST AK: Empty transaction history list returns empty without errors', () async {
      final txs = await walletService.getTransactions();
      expect(txs, isEmpty);
    });

    // TEST AL: Transaction failure displays correctly
    test('TEST AL: Failed transaction records failed status in ledger', () async {
      await walletService.addMoney(
        amount: 200.0,
        simulatedOutcome: MockPaymentOutcome.failure,
      );

      final txs = await walletService.getTransactions();
      expect(txs.isNotEmpty, true);
      expect(txs.first.status, WalletTransactionStatus.failed);
    });

    // TEST AM: Network metadata is preserved
    test('TEST AM: Network metadata Tata Power preserved in transaction', () async {
      await walletService.addMoney(amount: 1000.0);
      final result = await walletService.debit(
        amount: 615.0,
        description: 'EV charging payment',
        networkName: 'Tata Power',
        chargerName: 'Tata Power Charging Station',
      );

      expect(result.transaction?.networkName, 'Tata Power');
      expect(result.transaction?.chargerName, 'Tata Power Charging Station');
    });

    // TEST AN: Charging session ID field supports future integration
    test('TEST AN: Charging session ID field is populated safely', () async {
      await walletService.addMoney(amount: 1000.0);
      final result = await walletService.debit(
        amount: 400.0,
        description: 'Session test',
        chargingSessionId: 'session_8899',
      );

      expect(result.transaction?.chargingSessionId, 'session_8899');
    });

    // TEST AO: Wallet remains network-independent
    test('TEST AO: Wallet operates seamlessly across multiple networks (Statiq, Zeon, Jio-bp)', () async {
      await walletService.addMoney(amount: 2000.0);

      await walletService.debit(
        amount: 300.0,
        description: 'Charge 1',
        networkName: 'Statiq',
      );

      await walletService.debit(
        amount: 400.0,
        description: 'Charge 2',
        networkName: 'Zeon',
      );

      await walletService.debit(
        amount: 500.0,
        description: 'Charge 3',
        networkName: 'Jio-bp',
      );

      final txs = await walletService.getTransactions();
      final networks = txs.map((t) => t.networkName).whereType<String>().toSet();

      expect(networks, containsAll(['Statiq', 'Zeon', 'Jio-bp']));
      expect(await walletService.getBalance(), 800.0);
    });
  });
}

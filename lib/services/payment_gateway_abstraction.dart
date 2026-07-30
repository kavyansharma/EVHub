import 'dart:async';
import 'dart:math';

/// Simulated outcomes for mock payment gateway testing.
enum MockPaymentOutcome {
  success,
  failure,
  cancelled,
}

/// Structured response object returned by payment gateways.
class PaymentResult {
  final bool isSuccess;
  final String referenceId;
  final String? errorMessage;
  final MockPaymentOutcome outcome;

  const PaymentResult({
    required this.isSuccess,
    required this.referenceId,
    this.errorMessage,
    required this.outcome,
  });

  factory PaymentResult.success(String referenceId) {
    return PaymentResult(
      isSuccess: true,
      referenceId: referenceId,
      outcome: MockPaymentOutcome.success,
    );
  }

  factory PaymentResult.failure(String referenceId, String message) {
    return PaymentResult(
      isSuccess: false,
      referenceId: referenceId,
      errorMessage: message,
      outcome: MockPaymentOutcome.failure,
    );
  }

  factory PaymentResult.cancelled(String referenceId) {
    return PaymentResult(
      isSuccess: false,
      referenceId: referenceId,
      errorMessage: 'Payment cancelled by user',
      outcome: MockPaymentOutcome.cancelled,
    );
  }
}

/// Abstract contract for payment gateway orchestrators.
/// Allows future seamless integration with Razorpay, Stripe, UPI, etc.
abstract class PaymentGateway {
  Future<PaymentResult> initializePayment({
    required double amount,
    required String currency,
    required String paymentMethod,
  });

  Future<PaymentResult> processPayment({
    required double amount,
    required String currency,
    required String paymentMethod,
    MockPaymentOutcome simulatedOutcome = MockPaymentOutcome.success,
  });

  Future<PaymentResult> verifyPayment(String referenceId);

  Future<PaymentResult> refundPayment(String referenceId, double amount);
}

/// Active implementation used for simulation/demo phase.
class MockPaymentGateway implements PaymentGateway {
  final Random _random = Random();

  MockPaymentGateway();

  @override
  Future<PaymentResult> initializePayment({
    required double amount,
    required String currency,
    required String paymentMethod,
  }) async {
    final refId = _generateReferenceId();
    return PaymentResult.success(refId);
  }

  @override
  Future<PaymentResult> processPayment({
    required double amount,
    required String currency,
    required String paymentMethod,
    MockPaymentOutcome simulatedOutcome = MockPaymentOutcome.success,
  }) async {
    // Simulate network delay (100ms for fast testing, non-blocking)
    await Future.delayed(const Duration(milliseconds: 100));

    final refId = _generateReferenceId();

    switch (simulatedOutcome) {
      case MockPaymentOutcome.success:
        return PaymentResult.success(refId);
      case MockPaymentOutcome.failure:
        return PaymentResult.failure(
          refId,
          'Mock payment gateway declined transaction.',
        );
      case MockPaymentOutcome.cancelled:
        return PaymentResult.cancelled(refId);
    }
  }

  @override
  Future<PaymentResult> verifyPayment(String referenceId) async {
    return PaymentResult.success(referenceId);
  }

  @override
  Future<PaymentResult> refundPayment(String referenceId, double amount) async {
    final refundRef = 'MOCK-REFUND-${_generateReferenceId()}';
    return PaymentResult.success(refundRef);
  }

  String _generateReferenceId() {
    final dateStr = DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 8);
    final randNum = _random.nextInt(900000) + 100000;
    return 'MOCK-TXN-$dateStr-$randNum';
  }
}

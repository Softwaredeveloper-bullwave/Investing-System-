import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../domain/kyc_models.dart';
import 'dio_client.dart';

class KycRepository {
  final _client = KycDioClient.instance;

  Future<KycStatusModel> fetchStatus() async {
    final data = await _client.getJson('/kyc-status/');
    return KycStatusModel.fromJson(data);
  }

  Future<KycStatusModel> verifyPan(String pan, {String holderName = ''}) async {
    final data = await _client.postJson('/verify-pan/', body: {
      'pan_number': pan.toUpperCase(),
      if (holderName.isNotEmpty) 'holder_name': holderName,
    });
    return KycStatusModel.fromJson(data);
  }

  Future<KycStatusModel> verifyBank({
    required String accountHolderName,
    required String accountNumber,
    required String confirmAccountNumber,
    required String ifsc,
  }) async {
    final data = await _client.postJson('/verify-bank/', body: {
      'account_holder_name': accountHolderName,
      'account_number': accountNumber,
      'confirm_account_number': confirmAccountNumber,
      'ifsc': ifsc.toUpperCase(),
    });
    return KycStatusModel.fromJson(data);
  }

  Future<KycStatusModel> runNameMatch() async {
    final data = await _client.postJson('/name-match/');
    return KycStatusModel.fromJson(data);
  }
}

class PaymentRepository {
  final _client = KycDioClient.instance;

  Future<PaymentSessionModel> createPayment(double amount, {String returnUrl = ''}) async {
    try {
      final data = await _client.postJson('/create-payment/', body: {
        'amount': amount,
        if (returnUrl.isNotEmpty) 'return_url': returnUrl,
      });
      return PaymentSessionModel.fromJson(data);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      rethrow;
    }
  }

  Future<WithdrawResultModel> withdraw(double amount) async {
    try {
      final data = await _client.postJson('/withdraw/', body: {'amount': amount});
      return WithdrawResultModel.fromJson(data);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      rethrow;
    }
  }

  Future<String> paymentStatus(String orderId) async {
    final data = await _client.getJson('/payment-status/$orderId/');
    return data['status'] as String? ?? 'created';
  }
}

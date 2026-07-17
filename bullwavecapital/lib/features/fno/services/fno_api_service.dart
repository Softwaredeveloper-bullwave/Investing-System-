import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exception.dart';
import '../../kyc/data/dio_client.dart';
import '../models/fno_status_model.dart';

class FnoApiService {
  FnoApiService._();
  static final FnoApiService instance = FnoApiService._();

  final _client = KycDioClient.instance;

  Future<FnoStatusModel> fetchMe() async {
    final data = await _client.getJson('/fno/me/');
    return FnoStatusModel.fromJson(data);
  }

  Future<FnoStatusModel> submitProof({
    required String proofType,
    XFile? document,
  }) async {
    final form = FormData();
    form.fields.add(MapEntry('proof_type', proofType));

    if (document != null) {
      final bytes = await document.readAsBytes();
      final name = document.name.isNotEmpty ? document.name : 'document.jpg';
      form.files.add(
        MapEntry(
          'document',
          MultipartFile.fromBytes(bytes, filename: name),
        ),
      );
    }

    try {
      final res = await _client.dio.post<Map<String, dynamic>>(
        '/fno/submit/',
        data: form,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 90),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return FnoStatusModel.fromJson(res.data ?? {});
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      throw ApiException(
        e.response?.statusCode ?? 500,
        _extractMessage(e),
      );
    }
  }

  String _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Cannot reach server. Is Django running on port 8000?';
    }
    return e.message ?? 'F&O verification failed.';
  }
}

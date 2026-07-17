import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exception.dart';
import '../data/dio_client.dart';
import '../models/kyc_status_model.dart';

/// Manual KYC API — uses [ApiConfig.baseUrl] via [KycDioClient].
class KycApiService {
  KycApiService._();
  static final KycApiService instance = KycApiService._();

  final _client = KycDioClient.instance;
  static const maxPhotos = 5;

  Future<ManualKycStatusModel> fetchMe() async {
    final data = await _client.getJson('/kyc/me/');
    return ManualKycStatusModel.fromJson(data);
  }

  Future<ManualKycStatusModel> submitKyc({
    required String panNumber,
    required String fullName,
    required String dob,
    required List<XFile> panImages,
  }) async {
    if (panImages.isEmpty) {
      throw ApiException(400, 'At least one PAN photo is required.');
    }
    if (panImages.length > maxPhotos) {
      throw ApiException(400, 'You can upload up to $maxPhotos photos.');
    }

    final form = FormData();
    form.fields
      ..add(MapEntry('pan_number', panNumber.toUpperCase().trim()))
      ..add(MapEntry('full_name', fullName.trim()))
      ..add(MapEntry('dob', dob));

    for (var i = 0; i < panImages.length; i++) {
      final file = panImages[i];
      final bytes = await file.readAsBytes();
      final name = file.name.isNotEmpty ? file.name : 'pan_${i + 1}.jpg';
      form.files.add(
        MapEntry(
          'pan_image',
          MultipartFile.fromBytes(bytes, filename: name),
        ),
      );
    }

    try {
      final res = await _client.dio.post<Map<String, dynamic>>(
        '/kyc/submit/',
        data: form,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 90),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      final data = res.data ?? {};
      return ManualKycStatusModel.fromJson(data);
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
      if (detail is List && detail.isNotEmpty) return detail.first.toString();
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Cannot reach server. Is Django running?';
    }
    return e.message ?? 'KYC submission failed.';
  }
}

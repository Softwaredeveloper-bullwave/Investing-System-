import '../api/api_config.dart';

/// Routes news thumbnails through the Django proxy so images load on Flutter web.
String resolveNewsImageUrl(String imageUrl) {
  final url = imageUrl.trim();
  if (url.isEmpty) return '';
  final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '');
  return '$base/news/image-proxy/?url=${Uri.encodeComponent(url)}';
}

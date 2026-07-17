/// TradingView credentials and charting library URLs.
///
/// Pass at build time:
/// ```bash
/// flutter run -d chrome \
///   --dart-define=TRADINGVIEW_API_KEY=your-key \
///   --dart-define=TRADINGVIEW_CHARTING_LIBRARY_URL=https://your-cdn/charting_library/ \
///   --dart-define=TRADINGVIEW_UDF_BASE_URL=http://127.0.0.1:8000/api/v1/market/tradingview/udf
/// ```
///
/// When [chartingLibraryUrl] is empty the app uses TradingView's hosted widget
/// embed (candlesticks) — no API key required. Plug in your licensed library +
/// UDF URL when ready.
class TradingViewConfig {
  TradingViewConfig._();

  static const String _apiKey =
      String.fromEnvironment('TRADINGVIEW_API_KEY', defaultValue: '');
  static const String _chartingLibraryUrl =
      String.fromEnvironment('TRADINGVIEW_CHARTING_LIBRARY_URL', defaultValue: '');
  static const String _udfBaseUrl =
      String.fromEnvironment('TRADINGVIEW_UDF_BASE_URL', defaultValue: '');

  static String? _remoteApiKey;
  static String? _remoteLibraryUrl;
  static String? _remoteUdfBaseUrl;
  static String _remoteProvider = 'widget_embed';
  static bool _loaded = false;

  static String get apiKey => (_remoteApiKey ?? _apiKey).trim();
  static String get chartingLibraryUrl => (_remoteLibraryUrl ?? _chartingLibraryUrl).trim();
  static String get udfBaseUrl => (_remoteUdfBaseUrl ?? _udfBaseUrl).trim();
  static bool get usesChartingLibrary =>
      chartingLibraryUrl.isNotEmpty || _remoteProvider == 'charting_library';
  static bool get isEnabled => !usesChartingLibrary;

  static void applyRemoteConfig(Map<String, dynamic>? json) {
    if (json == null) return;
    _remoteApiKey = json['apiKey']?.toString();
    _remoteLibraryUrl = json['chartingLibraryUrl']?.toString();
    _remoteUdfBaseUrl = json['udfBaseUrl']?.toString();
    _remoteProvider = json['provider']?.toString() ?? 'widget_embed';
    _loaded = true;
  }

  static bool get isLoaded => _loaded;
}

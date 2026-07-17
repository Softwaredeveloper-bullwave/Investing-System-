import 'tradingview_config.dart';

/// Builds TradingView Advanced Chart widget embed URLs (hosted by TradingView).
class TradingViewEmbedUrl {
  TradingViewEmbedUrl._();

  static String build({
    required String symbol,
    required String interval,
    String theme = 'dark',
    String timezone = 'Asia/Kolkata',
  }) {
    final isLight = theme == 'light';
    final params = <String, String>{
      'symbol': symbol,
      'interval': interval,
      'timezone': timezone,
      'theme': isLight ? 'light' : 'dark',
      'style': '1',
      'locale': 'en',
      'enable_publishing': 'false',
      'allow_symbol_change': 'false',
      'save_image': 'false',
      'hide_top_toolbar': '0',
      'hide_legend': '0',
      'backgroundColor': isLight ? 'F4F4F0' : '050503',
      'gridColor': isLight ? 'E8E8E3' : '1a1a18',
      'withdateranges': '0',
    };

    if (TradingViewConfig.apiKey.isNotEmpty) {
      params['customer'] = TradingViewConfig.apiKey;
    }

    final query = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return 'https://s.tradingview.com/widgetembed/?$query';
  }
}

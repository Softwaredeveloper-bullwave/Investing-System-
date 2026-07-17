/// Maps app symbols to TradingView `EXCHANGE:SYMBOL` format.
class TradingViewSymbols {
  TradingViewSymbols._();

  static const _stockOverrides = {
    'M&M': 'NSE:M&M',
  };

  static const commodityIds = {
    'GOLD': 'TVC:GOLD',
    'SILVER': 'TVC:SILVER',
    'PLATINUM': 'TVC:PLATINUM',
    'CRUDE_OIL': 'TVC:USOIL',
    'BRENT_OIL': 'TVC:UKOIL',
    'NATURAL_GAS': 'TVC:NATURALGAS',
    'COPPER': 'COMEX:HG1!',
    'ALUMINUM': 'TVC:ALUMINUM',
  };

  /// UI label → TradingView interval token.
  static const intervalByLabel = {
    '1m': '1',
    '5m': '5',
    '30m': '30',
    '1H': '60',
    '1h': '60',
    '1D': 'D',
    '1d': 'D',
    '1M': 'M',
  };

  /// Backend/API interval → TradingView interval token.
  static const intervalByApi = {
    '1m': '1',
    '5m': '5',
    '30m': '30',
    '1h': '60',
    '1d': 'D',
    '90d': 'D',
  };

  static String stock(String symbol, {String exchange = 'NSE'}) {
    final sym = symbol.toUpperCase().trim();
    if (_stockOverrides.containsKey(sym)) return _stockOverrides[sym]!;
    if (sym.contains(':')) return sym;
    return '${exchange.toUpperCase()}:$sym';
  }

  static String commodity(String commodityId) {
    final id = commodityId.toUpperCase().trim();
    return commodityIds[id] ?? 'TVC:$id';
  }

  static String intervalForLabel(String label) =>
      intervalByLabel[label] ?? intervalByLabel[label.toLowerCase()] ?? 'D';

  static String intervalForApi(String apiInterval) =>
      intervalByApi[apiInterval] ?? 'D';
}

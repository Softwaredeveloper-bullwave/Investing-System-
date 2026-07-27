/// F&O index catalog — NSE & BSE index derivatives.
class FnoIndexCatalog {
  FnoIndexCatalog._();

  static const indices = <FnoIndexMeta>[
    FnoIndexMeta(symbol: 'NIFTY', label: 'Nifty 50', exchange: 'NSE', marketIndexKey: 'NIFTY'),
    FnoIndexMeta(symbol: 'SENSEX', label: 'Sensex', exchange: 'BSE', marketIndexKey: 'SENSEX'),
    FnoIndexMeta(symbol: 'BANKNIFTY', label: 'Bank Nifty', exchange: 'NSE', marketIndexKey: 'BANKNIFTY'),
    FnoIndexMeta(symbol: 'FINNIFTY', label: 'Finnifty', exchange: 'NSE', marketIndexKey: 'FINNIFTY'),
    FnoIndexMeta(symbol: 'MIDCPNIFTY', label: 'Nifty Midcap Select', exchange: 'NSE', marketIndexKey: 'MIDCPNIFTY'),
    FnoIndexMeta(symbol: 'BANKEX', label: 'BSE Bankex', exchange: 'BSE', marketIndexKey: 'BANKEX'),
  ];

  static FnoIndexMeta? bySymbol(String symbol) {
    final s = symbol.toUpperCase();
    try {
      return indices.firstWhere((i) => i.symbol == s);
    } catch (_) {
      return null;
    }
  }

  static bool isIndex(String symbol) => bySymbol(symbol) != null;
}

class FnoIndexMeta {
  final String symbol;
  final String label;
  final String exchange;
  final String marketIndexKey;

  const FnoIndexMeta({
    required this.symbol,
    required this.label,
    required this.exchange,
    required this.marketIndexKey,
  });
}

/// Legacy alias — keep option chain screen working.
class FnoUnderlyings {
  FnoUnderlyings._();

  static List<({String symbol, String label})> get indices =>
      FnoIndexCatalog.indices.map((i) => (symbol: i.symbol, label: i.label)).toList();

  // Full Nifty 50 — the option chain backend no longer gates on a curated
  // F&O-only subset (any stock now gets a synthetic chain), so the picker
  // offers the whole index instead of a smaller hand-picked list.
  static const stocks = [
    'RELIANCE', 'TCS', 'HDFCBANK', 'INFY', 'ICICIBANK', 'HINDUNILVR', 'ITC', 'SBIN',
    'BHARTIARTL', 'KOTAKBANK', 'LT', 'AXISBANK', 'ASIANPAINT', 'MARUTI', 'TITAN',
    'BAJFINANCE', 'HCLTECH', 'WIPRO', 'ULTRACEMCO', 'NESTLEIND', 'SUNPHARMA',
    'TMPV', 'M&M', 'NTPC', 'POWERGRID', 'ONGC', 'COALINDIA', 'JSWSTEEL',
    'TATASTEEL', 'ADANIENT', 'ADANIPORTS', 'TECHM', 'HDFCLIFE', 'SBILIFE',
    'BAJAJFINSV', 'GRASIM', 'CIPLA', 'BPCL', 'EICHERMOT', 'HEROMOTOCO',
    'DIVISLAB', 'DRREDDY', 'APOLLOHOSP', 'BRITANNIA', 'HINDALCO', 'INDUSINDBK',
    'TRENT', 'BEL', 'SHRIRAMFIN', 'JIOFIN',
  ];

  static bool isIndex(String symbol) => FnoIndexCatalog.isIndex(symbol);
}

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

  static const stocks = [
    'RELIANCE', 'TCS', 'HDFCBANK', 'INFY', 'ICICIBANK', 'SBIN', 'ITC', 'BHARTIARTL',
    'KOTAKBANK', 'AXISBANK', 'LT', 'MARUTI', 'TITAN', 'BAJFINANCE', 'HCLTECH',
    'WIPRO', 'TATAMOTORS', 'M&M', 'NTPC', 'ONGC', 'TATASTEEL', 'ADANIENT',
    'SUNPHARMA', 'TECHM', 'HINDALCO', 'JSWSTEEL',
  ];

  static bool isIndex(String symbol) => FnoIndexCatalog.isIndex(symbol);
}

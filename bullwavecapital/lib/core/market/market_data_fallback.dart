import '../../dummy/stock_dummy_data.dart';
import '../../models/market_index_model.dart';
import '../../models/stock_model.dart';

/// Offline NSE demo feed when backend / Kotak Neo is unavailable.
class MarketDataFallback {
  MarketDataFallback._();

  static const providerLabel = 'Demo NSE (configure Kotak Neo on backend)';

  static List<StockModel> get stocks => StockDummyData.nseStocks;

  static const indices = [
    MarketIndexModel(
      id: 'NIFTY50',
      name: 'Nifty 50',
      shortName: 'NIFTY',
      value: 24832.45,
      change: 156.30,
      changePercent: 0.63,
    ),
    MarketIndexModel(
      id: 'SENSEX',
      name: 'Sensex',
      shortName: 'SENSEX',
      value: 81524.78,
      change: 582.15,
      changePercent: 0.72,
    ),
    MarketIndexModel(
      id: 'BANKNIFTY',
      name: 'Bank Nifty',
      shortName: 'BANK NIFTY',
      value: 52318.60,
      change: -124.40,
      changePercent: -0.24,
    ),
  ];
}

import '../core/api/api_placeholders.dart';
import '../models/stock_model.dart';

class StockDummyData {
  StockDummyData._();

  static const List<String> defaultWatchlist = ['RELIANCE', 'TCS', 'INFY', 'HDFCBANK'];

  static const List<StockModel> nseStocks = [
    StockModel(
      symbol: 'RELIANCE',
      name: 'Reliance Industries',
      sector: 'Energy',
      ltp: 2948.50,
      change: 32.40,
      changePercent: 1.11,
      open: 2920.00,
      high: 2955.00,
      low: 2910.25,
      previousClose: 2916.10,
      volume: 8420000,
      marketCapCr: 1995000,
      pe: 28.4,
      eps: 103.8,
      week52High: 3210.00,
      week52Low: 2220.00,
    ),
    StockModel(
      symbol: 'TCS',
      name: 'Tata Consultancy Services',
      sector: 'IT',
      ltp: 4125.30,
      change: -18.70,
      changePercent: -0.45,
      open: 4148.00,
      high: 4155.00,
      low: 4110.00,
      previousClose: 4144.00,
      volume: 2150000,
      marketCapCr: 1502000,
      pe: 32.1,
      eps: 128.5,
      week52High: 4592.00,
      week52Low: 3311.00,
    ),
    StockModel(
      symbol: 'INFY',
      name: 'Infosys Ltd',
      sector: 'IT',
      ltp: 1882.15,
      change: 12.85,
      changePercent: 0.69,
      open: 1870.00,
      high: 1890.50,
      low: 1865.00,
      previousClose: 1869.30,
      volume: 4680000,
      marketCapCr: 782000,
      pe: 27.8,
      eps: 67.7,
      week52High: 2006.00,
      week52Low: 1350.00,
    ),
    StockModel(
      symbol: 'HDFCBANK',
      name: 'HDFC Bank',
      sector: 'Banking',
      ltp: 1724.80,
      change: 8.20,
      changePercent: 0.48,
      open: 1718.00,
      high: 1730.00,
      low: 1712.50,
      previousClose: 1716.60,
      volume: 6120000,
      marketCapCr: 1310000,
      pe: 19.2,
      eps: 89.8,
      week52High: 1880.00,
      week52Low: 1363.00,
    ),
    StockModel(
      symbol: 'ICICIBANK',
      name: 'ICICI Bank',
      sector: 'Banking',
      ltp: 1248.60,
      change: -5.40,
      changePercent: -0.43,
      open: 1256.00,
      high: 1258.00,
      low: 1242.00,
      previousClose: 1254.00,
      volume: 8940000,
      marketCapCr: 875000,
      pe: 18.5,
      eps: 67.4,
      week52High: 1312.00,
      week52Low: 912.00,
    ),
    StockModel(
      symbol: 'SBIN',
      name: 'State Bank of India',
      sector: 'Banking',
      ltp: 812.45,
      change: 14.25,
      changePercent: 1.79,
      open: 798.00,
      high: 816.00,
      low: 795.50,
      previousClose: 798.20,
      volume: 12500000,
      marketCapCr: 725000,
      pe: 10.8,
      eps: 75.2,
      week52High: 912.00,
      week52Low: 543.00,
    ),
    StockModel(
      symbol: 'BHARTIARTL',
      name: 'Bharti Airtel',
      sector: 'Telecom',
      ltp: 1588.90,
      change: 22.10,
      changePercent: 1.41,
      open: 1570.00,
      high: 1595.00,
      low: 1565.00,
      previousClose: 1566.80,
      volume: 3420000,
      marketCapCr: 905000,
      pe: 42.5,
      eps: 37.4,
      week52High: 1779.00,
      week52Low: 1098.00,
    ),
    StockModel(
      symbol: 'ITC',
      name: 'ITC Ltd',
      sector: 'FMCG',
      ltp: 478.25,
      change: -2.15,
      changePercent: -0.45,
      open: 481.00,
      high: 482.50,
      low: 476.00,
      previousClose: 480.40,
      volume: 9870000,
      marketCapCr: 598000,
      pe: 28.9,
      eps: 16.5,
      week52High: 528.00,
      week52Low: 392.00,
    ),
    StockModel(
      symbol: 'TATAMOTORS',
      name: 'Tata Motors',
      sector: 'Auto',
      ltp: 985.40,
      change: 28.60,
      changePercent: 2.99,
      open: 958.00,
      high: 992.00,
      low: 955.00,
      previousClose: 956.80,
      volume: 15600000,
      marketCapCr: 362000,
      pe: 14.2,
      eps: 69.4,
      week52High: 1179.00,
      week52Low: 542.00,
    ),
    StockModel(
      symbol: 'MARUTI',
      name: 'Maruti Suzuki',
      sector: 'Auto',
      ltp: 12456.00,
      change: 186.00,
      changePercent: 1.52,
      open: 12280.00,
      high: 12480.00,
      low: 12250.00,
      previousClose: 12270.00,
      volume: 890000,
      marketCapCr: 392000,
      pe: 28.6,
      eps: 435.5,
      week52High: 13680.00,
      week52Low: 9737.00,
    ),
    StockModel(
      symbol: 'BAJFINANCE',
      name: 'Bajaj Finance',
      sector: 'NBFC',
      ltp: 7256.80,
      change: -42.20,
      changePercent: -0.58,
      open: 7310.00,
      high: 7325.00,
      low: 7240.00,
      previousClose: 7299.00,
      volume: 1120000,
      marketCapCr: 448000,
      pe: 32.4,
      eps: 224.0,
      week52High: 8192.00,
      week52Low: 6187.00,
    ),
    StockModel(
      symbol: 'WIPRO',
      name: 'Wipro Ltd',
      sector: 'IT',
      ltp: 542.30,
      change: 4.80,
      changePercent: 0.89,
      open: 538.00,
      high: 545.00,
      low: 536.50,
      previousClose: 537.50,
      volume: 6780000,
      marketCapCr: 284000,
      pe: 22.1,
      eps: 24.5,
      week52High: 615.00,
      week52Low: 385.00,
    ),
    StockModel(
      symbol: 'AXISBANK',
      name: 'Axis Bank',
      sector: 'Banking',
      ltp: 1124.50,
      change: 6.30,
      changePercent: 0.56,
      open: 1118.00,
      high: 1128.00,
      low: 1112.00,
      previousClose: 1118.20,
      volume: 4560000,
      marketCapCr: 347000,
      pe: 13.2,
      eps: 85.2,
      week52High: 1339.00,
      week52Low: 915.00,
    ),
    StockModel(
      symbol: 'HINDUNILVR',
      name: 'Hindustan Unilever',
      sector: 'FMCG',
      ltp: 2388.00,
      change: -8.50,
      changePercent: -0.35,
      open: 2398.00,
      high: 2402.00,
      low: 2380.00,
      previousClose: 2396.50,
      volume: 1890000,
      marketCapCr: 561000,
      pe: 58.2,
      eps: 41.0,
      week52High: 2755.00,
      week52Low: 2172.00,
    ),
    StockModel(
      symbol: 'KOTAKBANK',
      name: 'Kotak Mahindra Bank',
      sector: 'Banking',
      ltp: 1788.20,
      change: 11.80,
      changePercent: 0.66,
      open: 1778.00,
      high: 1794.00,
      low: 1772.00,
      previousClose: 1776.40,
      volume: 2340000,
      marketCapCr: 355000,
      pe: 20.8,
      eps: 86.0,
      week52High: 2301.00,
      week52Low: 1679.00,
    ),
  ];

  static StockModel? findStock(String symbol) {
    try {
      return nseStocks.firstWhere((s) => s.symbol == symbol.toUpperCase());
    } catch (_) {
      return null;
    }
  }

  static List<CandleModel> generateCandles(String symbol, {int count = 30}) {
    final stock = findStock(symbol);
    final base = stock?.ltp ?? 1000.0;
    final now = DateTime.now();
    final candles = <CandleModel>[];
    var price = base * 0.92;

    for (var i = count - 1; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final open = price;
      final volatility = base * 0.012;
      final high = open + volatility * (0.4 + (i % 5) * 0.1);
      final low = open - volatility * (0.3 + (i % 4) * 0.1);
      final close = low + (high - low) * (0.35 + (i % 7) * 0.08);
      price = close;
      candles.add(CandleModel(
        time: day,
        open: open,
        high: high,
        low: low,
        close: close,
        volume: 1000000 + (i * 50000),
      ));
    }
    return candles;
  }

  static TechnicalIndicatorsModel indicatorsFor(String symbol) {
    final stock = findStock(symbol);
    final ltp = stock?.ltp ?? 1000;
    return TechnicalIndicatorsModel(
      rsi: 58.4 + (symbol.hashCode % 20),
      macdSignal: ltp > 1500 ? 'Bullish crossover' : 'Neutral',
      sma50: ltp * 0.97,
      sma200: ltp * 0.91,
      trend: stock?.isPositive == true ? 'Uptrend' : 'Sideways',
    );
  }

  static const List<StockHoldingModel> holdings = [
    StockHoldingModel(symbol: 'RELIANCE', name: 'Reliance Industries', quantity: 25, avgPrice: 2650, ltp: 2948.50),
    StockHoldingModel(symbol: 'TCS', name: 'Tata Consultancy Services', quantity: 15, avgPrice: 3850, ltp: 4125.30),
    StockHoldingModel(symbol: 'HDFCBANK', name: 'HDFC Bank', quantity: 40, avgPrice: 1580, ltp: 1724.80),
    StockHoldingModel(symbol: 'INFY', name: 'Infosys Ltd', quantity: 50, avgPrice: 1620, ltp: 1882.15),
  ];

  static final List<StockNewsModel> news = [
    StockNewsModel(
      id: 'N1',
      title: 'Nifty 50 hits fresh record as banking stocks rally',
      summary: 'Benchmark indices gained for the third straight session led by HDFC Bank and ICICI Bank.',
      source: 'Economic Times',
      publishedAt: DateTime(2025, 6, 27, 9, 30),
      relatedSymbols: ['NIFTY', 'HDFCBANK', 'ICICIBANK'],
      category: 'Markets',
    ),
    StockNewsModel(
      id: 'N2',
      title: 'Reliance Jio announces 5G expansion in tier-2 cities',
      summary: 'Reliance Industries subsidiary plans network rollout across 200 cities by Q3.',
      source: 'Moneycontrol',
      publishedAt: DateTime(2025, 6, 26, 14, 15),
      relatedSymbols: ['RELIANCE'],
      category: 'Corporate',
    ),
    StockNewsModel(
      id: 'N3',
      title: 'IT sector outlook remains strong amid AI demand',
      summary: 'Analysts upgrade TCS and Infosys citing robust deal pipeline and margin stability.',
      source: 'Bloomberg Quint',
      publishedAt: DateTime(2025, 6, 26, 11, 0),
      relatedSymbols: ['TCS', 'INFY', 'WIPRO'],
      category: 'Sector',
    ),
    StockNewsModel(
      id: 'N4',
      title: 'RBI keeps repo rate unchanged at 6.5%',
      summary: 'Policy stance remains neutral; banking stocks react positively in early trade.',
      source: 'Livemint',
      publishedAt: DateTime(2025, 6, 25, 10, 0),
      relatedSymbols: ['SBIN', 'AXISBANK', 'KOTAKBANK'],
      category: 'Economy',
    ),
    StockNewsModel(
      id: 'N5',
      title: 'Tata Motors EV sales cross 1 lakh units milestone',
      summary: 'Strong demand for Nexon EV and Punch EV drives quarterly revenue beat.',
      source: 'Business Standard',
      publishedAt: DateTime(2025, 6, 24, 16, 45),
      relatedSymbols: ['TATAMOTORS'],
      category: 'Auto',
    ),
  ];

  static final List<PriceAlertModel> priceAlerts = [
    PriceAlertModel(id: 'A1', symbol: 'RELIANCE', name: 'Reliance Industries', targetPrice: 3000, condition: 'Above'),
    PriceAlertModel(id: 'A2', symbol: 'TCS', name: 'Tata Consultancy Services', targetPrice: 4000, condition: 'Below'),
    PriceAlertModel(id: 'A3', symbol: 'TATAMOTORS', name: 'Tata Motors', targetPrice: 1000, condition: 'Above'),
  ];

  static final List<SipPlanModel> sipPlans = [
    SipPlanModel(
      id: 'S1',
      symbol: 'INFY',
      name: 'Infosys Ltd',
      monthlyAmount: 5000,
      installmentsDone: 18,
      totalInstallments: 36,
      totalInvested: 90000,
      currentValue: 98500,
      nextDate: DateTime(2025, 7, 5),
    ),
    SipPlanModel(
      id: 'S2',
      symbol: 'HDFCBANK',
      name: 'HDFC Bank',
      monthlyAmount: 10000,
      installmentsDone: 24,
      totalInstallments: 60,
      totalInvested: 240000,
      currentValue: 268400,
      nextDate: DateTime(2025, 7, 10),
    ),
  ];

  static List<OptionContractModel> optionChain(String symbol) {
    final spot = findStock(symbol)?.ltp ?? 2500.0;
    final expiry = DateTime(2025, 7, 31);
    return [
      for (var i = -2; i <= 2; i++)
        OptionContractModel(
          symbol: symbol,
          strike: (spot / 50).round() * 50.0 + (i * 50),
          type: 'CE',
          ltp: 45.5 + i * 8,
          change: 2.1,
          oi: 125000 + i * 10000,
          volume: 45000,
          expiry: expiry,
        ),
      for (var i = -2; i <= 2; i++)
        OptionContractModel(
          symbol: symbol,
          strike: (spot / 50).round() * 50.0 + (i * 50),
          type: 'PE',
          ltp: 38.2 + i * 6,
          change: -1.4,
          oi: 98000 + i * 8000,
          volume: 32000,
          expiry: expiry,
        ),
    ];
  }

  static final List<PaperTradeModel> paperTrades = [
    PaperTradeModel(
      id: 'P1',
      symbol: 'RELIANCE',
      side: 'BUY',
      quantity: 10,
      price: 2900,
      time: DateTime(2025, 6, 26, 10, 15),
      status: 'Filled',
    ),
    PaperTradeModel(
      id: 'P2',
      symbol: 'TATAMOTORS',
      side: 'SELL',
      quantity: 25,
      price: 960,
      time: DateTime(2025, 6, 25, 14, 30),
      status: 'Filled',
      avgCost: 920,
      realizedPnl: 1000,
      realizedPnlPercent: 4.35,
      orderValue: 24000,
    ),
  ];

  static final List<DividendModel> dividends = [
    DividendModel(
      symbol: 'ITC',
      name: 'ITC Ltd',
      amountPerShare: 6.25,
      exDate: DateTime(2025, 5, 15),
      paymentDate: DateTime(2025, 6, 10),
      sharesHeld: 100,
      status: 'Credited',
    ),
    DividendModel(
      symbol: 'HDFCBANK',
      name: 'HDFC Bank',
      amountPerShare: 19.50,
      exDate: DateTime(2025, 6, 20),
      paymentDate: DateTime(2025, 7, 15),
      sharesHeld: 40,
      status: 'Upcoming',
    ),
  ];

  static List<ScreenerStockModel> screenerResults = nseStocks
      .map(
        (s) => ScreenerStockModel(
          stock: s,
          roe: 12 + (s.symbol.hashCode % 18),
          debtToEquity: 0.2 + (s.symbol.hashCode % 10) / 10,
          revenueGrowth: 5 + (s.symbol.hashCode % 25),
        ),
      )
      .toList();

  static const List<String> aiSuggestions = [
    'What is the outlook for RELIANCE?',
    'Compare TCS vs INFY',
    'Best banking stocks today?',
    'Explain RSI indicator',
  ];

  static String aiResponse(String query) {
    final q = query.toLowerCase();
    if (q.contains('reliance')) {
      return 'Reliance Industries is trading near ₹2,948 with +1.11% today. '
          'RSI at 62 suggests moderate momentum. Key support: ₹2,850 | Resistance: ₹3,000. '
          '⚠️ Dummy AI response — connect ${ApiPlaceholders.aiChat} for real analysis.';
    }
    if (q.contains('tcs') || q.contains('infy')) {
      return 'TCS (₹4,125, -0.45%) vs Infosys (₹1,882, +0.69%): Infosys showing stronger intraday momentum. '
          'TCS has higher market cap and stability; INFY offers better short-term relative strength today.';
    }
    if (q.contains('rsi')) {
      return 'RSI (Relative Strength Index) measures momentum on a 0–100 scale. '
          'Above 70 = overbought, below 30 = oversold. Use with trend confirmation, not alone.';
    }
    return 'Based on current NSE data, large-cap IT and banking sectors are leading today. '
        'Consider diversifying across sectors. ⚠️ Dummy AI — backend needed at ${ApiPlaceholders.aiChat}.';
  }
}

/// Backend API endpoints — implement when connecting real services.
/// Suggested providers: NSE/BSE quote API, Alpha Vantage, Yahoo Finance, or broker APIs (Zerodha Kite).
class ApiPlaceholders {
  ApiPlaceholders._();

  // ── Auth (partially implemented with dummy OTP) ──
  static const sendOtp = 'POST /api/v1/auth/send-otp';
  static const verifyOtp = 'POST /api/v1/auth/verify-otp';

  // ── Stocks & live prices ──
  static const searchStocks = 'GET /api/v1/stocks/search?q={query}&exchange=NSE';
  static const stockQuote = 'GET /api/v1/stocks/{symbol}/quote';
  static const stockCandles = 'GET /api/v1/stocks/{symbol}/candles?interval={1d|1h|5m}';
  static const livePricesWs = 'WS /api/v1/stocks/live'; // WebSocket for LTP stream

  // ── Watchlist ──
  static const watchlist = 'GET /api/v1/watchlist';
  static const addWatchlist = 'POST /api/v1/watchlist/{symbol}';
  static const removeWatchlist = 'DELETE /api/v1/watchlist/{symbol}';

  // ── Portfolio ──
  static const holdings = 'GET /api/v1/portfolio/holdings';
  static const portfolioAnalytics = 'GET /api/v1/portfolio/analytics';

  // ── News ──
  static const stockNews = 'GET /api/v1/news?symbol={symbol}&limit=20';

  // ── Alerts ──
  static const priceAlerts = 'GET /api/v1/alerts';
  static const createAlert = 'POST /api/v1/alerts';

  // ── SIP ──
  static const sipPlans = 'GET /api/v1/sip';
  static const createSip = 'POST /api/v1/sip';

  // ── F&O ──
  static const optionChain = 'GET /api/v1/options/{symbol}/chain?expiry={date}';
  static const paperOrders = 'GET /api/v1/paper-trading/orders';
  static const placePaperOrder = 'POST /api/v1/paper-trading/orders';

  // ── Screener ──
  static const screener = 'GET /api/v1/screener?filters={json}';

  // ── Dividends ──
  static const dividends = 'GET /api/v1/dividends';

  // ── AI Assistant ──
  static const aiChat = 'POST /api/v1/ai/stock-assistant';
}

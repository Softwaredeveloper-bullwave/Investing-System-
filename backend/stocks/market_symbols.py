"""NSE symbols used for screener and F&O."""

# Nifty 50 constituents (NSE symbols)
NIFTY_50 = [
    'RELIANCE', 'TCS', 'HDFCBANK', 'INFY', 'ICICIBANK', 'HINDUNILVR', 'ITC', 'SBIN',
    'BHARTIARTL', 'KOTAKBANK', 'LT', 'AXISBANK', 'ASIANPAINT', 'MARUTI', 'TITAN',
    'BAJFINANCE', 'HCLTECH', 'WIPRO', 'ULTRACEMCO', 'NESTLEIND', 'SUNPHARMA',
    'TMPV', 'M&M', 'NTPC', 'POWERGRID', 'ONGC', 'COALINDIA', 'JSWSTEEL',
    'TATASTEEL', 'ADANIENT', 'ADANIPORTS', 'TECHM', 'HDFCLIFE', 'SBILIFE',
    'BAJAJFINSV', 'GRASIM', 'CIPLA', 'BPCL', 'EICHERMOT', 'HEROMOTOCO',
    'DIVISLAB', 'DRREDDY', 'APOLLOHOSP', 'BRITANNIA', 'HINDALCO', 'INDUSINDBK',
    'TRENT', 'BEL', 'SHRIRAMFIN', 'JIOFIN',
]

# Index / stock symbols with F&O segment
FNO_INDICES = {
    'NIFTY': '^NSEI',
    'BANKNIFTY': '^NSEBANK',
    'FINNIFTY': 'NIFTY_FIN_SERVICE.NS',
    'SENSEX': '^BSESN',
    'MIDCPNIFTY': '^NSMIDCP',
    'BANKEX': '^BSEBANK',
}

# Popular F&O stocks (equity derivatives)
FNO_STOCKS = [
    'RELIANCE', 'TCS', 'HDFCBANK', 'INFY', 'ICICIBANK', 'SBIN', 'ITC', 'BHARTIARTL',
    'KOTAKBANK', 'AXISBANK', 'LT', 'MARUTI', 'TITAN', 'BAJFINANCE', 'HCLTECH',
    'WIPRO', 'TATAMOTORS', 'M&M', 'NTPC', 'ONGC', 'TATASTEEL', 'ADANIENT',
    'SUNPHARMA', 'TECHM', 'HINDALCO', 'JSWSTEEL',
]

SECTOR_MAP = {
    'Financial Services': 'Banking',
    'Consumer Defensive': 'FMCG',
    'Consumer Cyclical': 'Auto',
    'Communication Services': 'Telecom',
    'Energy': 'Energy',
    'Basic Materials': 'Metals',
    'Industrials': 'Industrial',
    'Healthcare': 'Pharma',
    'Technology': 'IT',
    'Utilities': 'Power',
    'Real Estate': 'Realty',
}

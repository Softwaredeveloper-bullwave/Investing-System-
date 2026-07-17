/// Economic calendar events — RBI, inflation, GDP, earnings, and macro impact.
class EconomicCalendarEvent {
  final String id;
  final String country;
  final String countryCode;
  final String title;
  final String time;
  final String dateLabel;
  final int impact; // 1 low, 2 medium, 3 high
  final String? previous;
  final String? forecast;
  final String? actual;
  final String category;
  final String impactLabel;
  final String marketImpact;
  final List<String> relatedSymbols;

  const EconomicCalendarEvent({
    required this.id,
    required this.country,
    required this.countryCode,
    required this.title,
    required this.time,
    required this.dateLabel,
    required this.impact,
    this.previous,
    this.forecast,
    this.actual,
    this.category = 'Macro',
    this.impactLabel = '',
    this.marketImpact = '',
    this.relatedSymbols = const [],
  });

  bool get isHighImpact => impact >= 3;

  String get displayImpactLabel {
    if (impactLabel.isNotEmpty) return impactLabel;
    if (impact >= 3) return 'High';
    if (impact == 2) return 'Medium';
    return 'Low';
  }
}

class EconomicCalendarMockData {
  EconomicCalendarMockData._();

  static const filterCategories = [
    'All',
    'RBI Policy',
    'Inflation',
    'GDP',
    'Earnings',
    'Global',
  ];

  static List<EconomicCalendarEvent> byCategory(String category) {
    if (category == 'All') return events;
    if (category == 'Global') {
      return events.where((e) => e.countryCode != 'IN').toList();
    }
    if (category == 'RBI Policy') {
      return events
          .where(
            (e) =>
                e.category == 'RBI Policy' ||
                (e.category == 'Central Bank' && e.countryCode == 'IN'),
          )
          .toList();
    }
    return events.where((e) => e.category == category).toList();
  }

  static const events = [
    EconomicCalendarEvent(
      id: '1',
      country: 'India',
      countryCode: 'IN',
      title: 'CPI Inflation (YoY)',
      time: '5:30 PM',
      dateLabel: 'Today',
      impact: 3,
      previous: '4.8%',
      forecast: '4.6%',
      actual: null,
      category: 'Inflation',
      impactLabel: 'High',
      marketImpact: 'Hot CPI can delay RBI cuts; banks & rate-sensitives react first.',
    ),
    EconomicCalendarEvent(
      id: '2',
      country: 'India',
      countryCode: 'IN',
      title: 'WPI Inflation (YoY)',
      time: '12:00 PM',
      dateLabel: 'Today',
      impact: 2,
      previous: '2.4%',
      forecast: '2.6%',
      category: 'Inflation',
      impactLabel: 'Medium',
      marketImpact: 'Wholesale prices guide commodity and manufacturing names.',
    ),
    EconomicCalendarEvent(
      id: '3',
      country: 'India',
      countryCode: 'IN',
      title: 'RBI MPC Policy Decision',
      time: '10:00 AM',
      dateLabel: 'Tomorrow',
      impact: 3,
      previous: '6.50%',
      forecast: '6.50%',
      category: 'RBI Policy',
      impactLabel: 'High',
      marketImpact: 'Repo hold/cut drives Nifty Bank, NBFCs, and bond yields.',
    ),
    EconomicCalendarEvent(
      id: '4',
      country: 'India',
      countryCode: 'IN',
      title: 'RBI Governor Press Conference',
      time: '10:30 AM',
      dateLabel: 'Tomorrow',
      impact: 3,
      previous: '—',
      forecast: '—',
      category: 'RBI Policy',
      impactLabel: 'High',
      marketImpact: 'Guidance on inflation path and liquidity moves INR & banks.',
    ),
    EconomicCalendarEvent(
      id: '5',
      country: 'India',
      countryCode: 'IN',
      title: 'GDP Growth (QoQ / YoY)',
      time: '5:30 PM',
      dateLabel: 'Wed',
      impact: 3,
      previous: '6.7%',
      forecast: '6.5%',
      category: 'GDP',
      impactLabel: 'High',
      marketImpact: 'Strong GDP supports cyclicals; miss hits midcaps & infra.',
    ),
    EconomicCalendarEvent(
      id: '6',
      country: 'India',
      countryCode: 'IN',
      title: 'IIP Growth (YoY)',
      time: '5:30 PM',
      dateLabel: 'Wed',
      impact: 2,
      previous: '3.2%',
      forecast: '3.5%',
      category: 'GDP',
      impactLabel: 'Medium',
      marketImpact: 'Industrial output cue for capital goods and metals.',
    ),
    EconomicCalendarEvent(
      id: '7',
      country: 'India',
      countryCode: 'IN',
      title: 'TCS Q1 Earnings',
      time: 'After market',
      dateLabel: 'Wed',
      impact: 3,
      previous: '₹12.5 EPS',
      forecast: '₹13.1 EPS',
      category: 'Earnings',
      impactLabel: 'High',
      marketImpact: 'IT bellwether — guides Nifty IT and broader sentiment.',
      relatedSymbols: ['TCS', 'INFY', 'WIPRO'],
    ),
    EconomicCalendarEvent(
      id: '8',
      country: 'United States',
      countryCode: 'US',
      title: 'Non-Farm Payrolls',
      time: '7:00 PM',
      dateLabel: 'Tomorrow',
      impact: 3,
      previous: '227K',
      forecast: '180K',
      category: 'Employment',
      impactLabel: 'High',
      marketImpact: 'US jobs print moves Fed odds, USDINR, and FIIs.',
    ),
    EconomicCalendarEvent(
      id: '9',
      country: 'India',
      countryCode: 'IN',
      title: 'HDFC Bank Q1 Earnings',
      time: 'After market',
      dateLabel: 'Thu',
      impact: 3,
      previous: '₹20.8 EPS',
      forecast: '₹21.4 EPS',
      category: 'Earnings',
      impactLabel: 'High',
      marketImpact: 'Private bank leader — impacts Bank Nifty heavily.',
      relatedSymbols: ['HDFCBANK', 'ICICIBANK', 'KOTAKBANK'],
    ),
    EconomicCalendarEvent(
      id: '10',
      country: 'India',
      countryCode: 'IN',
      title: 'GST Collections',
      time: '4:00 PM',
      dateLabel: 'Thu',
      impact: 1,
      previous: '₹1.78L Cr',
      forecast: '₹1.80L Cr',
      category: 'Fiscal',
      impactLabel: 'Low',
      marketImpact: 'Soft cue on consumption and fiscal health.',
    ),
    EconomicCalendarEvent(
      id: '11',
      country: 'Eurozone',
      countryCode: 'EU',
      title: 'ECB Interest Rate Decision',
      time: '6:15 PM',
      dateLabel: 'Thu',
      impact: 3,
      previous: '3.65%',
      forecast: '3.40%',
      category: 'Central Bank',
      impactLabel: 'High',
      marketImpact: 'Euro rates shift global liquidity and IT exporters.',
    ),
    EconomicCalendarEvent(
      id: '12',
      country: 'India',
      countryCode: 'IN',
      title: 'Reliance Industries Q1 Earnings',
      time: 'After market',
      dateLabel: 'Fri',
      impact: 3,
      previous: '₹18.2 EPS',
      forecast: '₹19.0 EPS',
      category: 'Earnings',
      impactLabel: 'High',
      marketImpact: 'Index heavyweight — oil-to-retail mix moves Sensex.',
      relatedSymbols: ['RELIANCE'],
    ),
    EconomicCalendarEvent(
      id: '13',
      country: 'India',
      countryCode: 'IN',
      title: 'Trade Balance',
      time: '5:00 PM',
      dateLabel: 'Fri',
      impact: 2,
      previous: '-\$20.5B',
      forecast: '-\$19.8B',
      category: 'Trade',
      impactLabel: 'Medium',
      marketImpact: 'Deficit vs CAD narrative for INR and exporters.',
    ),
    EconomicCalendarEvent(
      id: '14',
      country: 'United States',
      countryCode: 'US',
      title: 'Core PCE Price Index',
      time: '7:30 PM',
      dateLabel: 'Fri',
      impact: 3,
      previous: '2.8%',
      forecast: '2.7%',
      category: 'Inflation',
      impactLabel: 'High',
      marketImpact: 'Fed’s preferred inflation gauge — risk-on/off for India.',
    ),
    EconomicCalendarEvent(
      id: '15',
      country: 'India',
      countryCode: 'IN',
      title: 'GVA / Manufacturing GDP Detail',
      time: '5:30 PM',
      dateLabel: 'Next week',
      impact: 2,
      previous: '5.9%',
      forecast: '6.1%',
      category: 'GDP',
      impactLabel: 'Medium',
      marketImpact: 'Sector GDP split cues autos, cement, and industrials.',
    ),
    EconomicCalendarEvent(
      id: '16',
      country: 'India',
      countryCode: 'IN',
      title: 'Infosys Q1 Earnings',
      time: 'After market',
      dateLabel: 'Next week',
      impact: 3,
      previous: '₹16.4 EPS',
      forecast: '₹16.9 EPS',
      category: 'Earnings',
      impactLabel: 'High',
      marketImpact: 'Deal wins & guidance set IT pack tone.',
      relatedSymbols: ['INFY', 'TCS', 'HCLTECH'],
    ),
    EconomicCalendarEvent(
      id: '17',
      country: 'India',
      countryCode: 'IN',
      title: 'RBI Liquidity / VRR Auction Result',
      time: '—',
      dateLabel: 'Next week',
      impact: 2,
      previous: '—',
      forecast: '—',
      category: 'RBI Policy',
      impactLabel: 'Medium',
      marketImpact: 'Surplus/deficit liquidity moves short rates and NBFCs.',
    ),
    EconomicCalendarEvent(
      id: '18',
      country: 'United States',
      countryCode: 'US',
      title: 'Fed Chair Speech',
      time: '9:30 PM',
      dateLabel: 'Wed',
      impact: 2,
      previous: '—',
      forecast: '—',
      category: 'Central Bank',
      impactLabel: 'Medium',
      marketImpact: 'Hawkish tone can pressure EM equities and INR.',
    ),
  ];
}

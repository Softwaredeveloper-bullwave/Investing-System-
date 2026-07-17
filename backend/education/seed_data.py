"""Investment education catalog — update here, then run: python manage.py seed_education"""

CATALOG = [
    {
        'slug': 'beginner',
        'title': 'Beginner',
        'subtitle': 'Start here — markets, demat & first steps',
        'icon_name': 'school',
        'accent_hex': '#3B82F6',
        'sort_order': 1,
        'articles': [
            {
                'slug': 'what-is-stock-market',
                'title': 'What is the Indian stock market? (2025)',
                'summary': 'NSE, BSE, indices, and how retail investors participate today.',
                'read_minutes': 5,
                'level': 'Beginner',
                'sections': [
                    'India\'s primary equity markets are the National Stock Exchange (NSE) and Bombay Stock Exchange (BSE). Companies list equity shares so investors can participate in ownership and long-term growth.',
                    'NIFTY 50 (NSE) and SENSEX (BSE) are benchmark indices tracking large, liquid stocks. Most beginners use them as reference points — not as direct investments unless via index funds or ETFs.',
                    'Retail participation has grown sharply post-COVID, with stronger digital KYC, UPI-based investing flows, and mobile-first brokers.',
                    'To start: PAN, Aadhaar-linked KYC, active bank account, and a SEBI-registered broker offering demat + trading.',
                    'Beginner rule: learn the app flow (Markets → Portfolio → Wallet), start small, and avoid F&O until basics are clear.',
                ],
            },
            {
                'slug': 'demat-and-trading',
                'title': 'Demat, trading account & order types',
                'summary': 'Electronic holdings, order types, and T+1 settlement.',
                'read_minutes': 4,
                'level': 'Beginner',
                'sections': [
                    'Demat holds shares electronically. Trading account routes buy/sell orders to the exchange via your broker.',
                    'Market order: fastest execution at prevailing prices. Limit order: executes only at your chosen price or better.',
                    'India follows T+1 settlement for equities — delivery typically reflects on the next working day after the trade.',
                    'Always verify available Wallet balance and open orders before placing new trades.',
                    'Use Notes in BullWave to record why you entered a trade — discipline starts on day one.',
                ],
            },
            {
                'slug': 'beginner-checklist',
                'title': 'Beginner checklist before your first trade',
                'summary': 'Practical steps for new Indian investors.',
                'read_minutes': 3,
                'level': 'Beginner',
                'sections': [
                    '1. Complete KYC and link your primary bank account.',
                    '2. Define goal: investing (years) vs trading (weeks/days) — different skills and risk.',
                    '3. Keep 6 months expenses outside the market as emergency buffer.',
                    '4. Start with large-cap stocks or diversified index funds; avoid single small-cap bets initially.',
                    '5. Document entry, target, and exit in Notes before buying.',
                    '6. Understand charges: brokerage, STT, exchange fees, GST, and capital gains tax.',
                    '7. Read one Documents topic per week and take a Quiz to reinforce learning.',
                ],
            },
        ],
    },
    {
        'slug': 'technical_analysis',
        'title': 'Technical Analysis',
        'subtitle': 'Charts, trends, support & resistance',
        'icon_name': 'show_chart',
        'accent_hex': '#22D3EE',
        'sort_order': 2,
        'articles': [
            {
                'slug': 'ta-basics',
                'title': 'Technical analysis basics',
                'summary': 'Price, volume, and timeframe analysis for NSE stocks.',
                'level': 'Intermediate',
                'sections': [
                    'TA studies historical price/volume — probability, not certainty.',
                    'Identify trend via swing highs/lows. Trade with the dominant trend on your chosen timeframe.',
                    'Support/resistance zones mark areas of prior demand/supply.',
                    'Combine TA with strict risk limits — patterns fail often.',
                ],
            },
            {
                'slug': 'indicators',
                'title': 'Moving averages & RSI',
                'summary': 'Common indicators on Indian charts.',
                'level': 'Intermediate',
                'sections': [
                    '50/200-day moving averages help gauge medium/long trend context.',
                    'RSI above 70 suggests strong momentum; below 30 weak momentum — context only.',
                    'Use BullWave TradingView charts to practice marking levels before live trades.',
                ],
            },
        ],
    },
    {
        'slug': 'fundamental_analysis',
        'title': 'Fundamental Analysis',
        'subtitle': 'Business quality, earnings & valuation',
        'icon_name': 'analytics',
        'accent_hex': '#10B981',
        'sort_order': 3,
        'articles': [
            {
                'slug': 'fa-basics',
                'title': 'Fundamental analysis basics',
                'summary': 'Evaluating listed Indian companies.',
                'sections': [
                    'Study revenue growth, margins, ROE, debt, and cash flows in annual reports and investor presentations.',
                    'Compare PE within sector — high PE may mean high growth expectations.',
                    'Quality: governance, promoter holding, pledge data, auditor notes.',
                ],
            },
            {
                'slug': 'reading-results',
                'title': 'Reading quarterly results',
                'summary': 'What matters in NSE/BSE earnings season.',
                'level': 'Intermediate',
                'sections': [
                    'Track YoY and QoQ revenue, EBITDA, and PAT — adjust for one-offs.',
                    'Read management commentary on demand, pricing, and capex.',
                    'Save your pre-result thesis in Notes and compare after numbers release.',
                ],
            },
        ],
    },
    {
        'slug': 'options',
        'title': 'Options',
        'subtitle': 'Calls, puts & option chain',
        'icon_name': 'call_made',
        'accent_hex': '#9333EA',
        'sort_order': 4,
        'articles': [
            {
                'slug': 'options-intro',
                'title': 'Options explained',
                'summary': 'Rights without obligation on NSE F&O.',
                'level': 'Intermediate',
                'sections': [
                    'Call = right to buy; Put = right to sell at strike before/on expiry.',
                    'Buyers risk premium paid; sellers carry margin and tail risk.',
                    'Complete F&O verification before live option trading.',
                ],
            },
        ],
    },
    {
        'slug': 'futures',
        'title': 'Futures',
        'subtitle': 'Leverage, margin & hedging',
        'icon_name': 'timeline',
        'accent_hex': '#6366F1',
        'sort_order': 5,
        'articles': [
            {
                'slug': 'futures-intro',
                'title': 'Futures basics',
                'summary': 'NSE index/stock futures and daily MTM.',
                'level': 'Intermediate',
                'sections': [
                    'Futures are leveraged contracts with daily mark-to-market.',
                    'Used for hedging or short-term directional views — not beginner territory.',
                ],
            },
        ],
    },
    {
        'slug': 'commodities',
        'title': 'Commodities',
        'subtitle': 'Gold, silver, crude & MCX',
        'icon_name': 'diamond',
        'accent_hex': '#F59E0B',
        'sort_order': 6,
        'articles': [
            {
                'slug': 'commodities-intro',
                'title': 'Commodity markets in India',
                'summary': 'MCX and portfolio diversification.',
                'sections': [
                    'Gold and crude react to global macros, USD, and geopolitics.',
                    'Use Commodities section in BullWave for live quotes before trading.',
                ],
            },
        ],
    },
    {
        'slug': 'mutual_funds',
        'title': 'Mutual Funds',
        'subtitle': 'SIP, NAV & categories',
        'icon_name': 'pie_chart',
        'accent_hex': '#EC4899',
        'sort_order': 7,
        'articles': [
            {
                'slug': 'mf-basics',
                'title': 'Mutual funds & SIP (2025)',
                'summary': 'Pool investing for long-term goals.',
                'sections': [
                    'SIP automates investing monthly — rupee cost averaging over time.',
                    'Choose category by risk: large-cap (lower volatility) vs mid/small-cap (higher).',
                    'Prefer direct plans for lower expense ratios.',
                ],
            },
        ],
    },
    {
        'slug': 'ipo',
        'title': 'IPO',
        'subtitle': 'Applying, allotment & listing',
        'icon_name': 'apartment',
        'accent_hex': '#0EA5E9',
        'sort_order': 8,
        'articles': [
            {
                'slug': 'ipo-process',
                'title': 'How IPOs work in India',
                'summary': 'UPI ASBA flow and listing day dynamics.',
                'sections': [
                    'Apply via broker UPI ASBA during open dates — funds blocked until allotment.',
                    'Read DRHP for business risks; avoid hype-only decisions.',
                    'Track dates in BullWave IPO Calendar.',
                ],
            },
        ],
    },
    {
        'slug': 'trading_psychology',
        'title': 'Trading Psychology',
        'subtitle': 'Discipline, bias & emotional control',
        'icon_name': 'psychology',
        'accent_hex': '#8B5CF6',
        'sort_order': 9,
        'articles': [
            {
                'slug': 'psych-basics',
                'title': 'Psychology beats strategy',
                'summary': 'Mindset for surviving markets.',
                'sections': [
                    'FOMO and revenge trading destroy accounts faster than bad analysis.',
                    'Journal outcomes in Notes — review weekly.',
                ],
            },
        ],
    },
    {
        'slug': 'risk_management',
        'title': 'Risk Management',
        'subtitle': 'Position size, stop-loss & capital rules',
        'icon_name': 'shield',
        'accent_hex': '#EF4444',
        'sort_order': 10,
        'articles': [
            {
                'slug': 'position-sizing',
                'title': 'Position sizing 101',
                'summary': 'Risk per trade and concentration limits.',
                'sections': [
                    'Risk 1–2% of trading capital per trade based on stop distance.',
                    'Limit single-stock exposure unless you accept concentration risk.',
                ],
            },
        ],
    },
    {
        'slug': 'quizzes',
        'title': 'Quizzes',
        'subtitle': 'Test your knowledge',
        'icon_name': 'quiz',
        'accent_hex': '#14B8A6',
        'sort_order': 11,
        'articles': [],
        'quizzes': [
            {
                'slug': 'quiz-beginner',
                'title': 'Beginner basics quiz',
                'description': '5 questions on markets, demat, and safe habits.',
                'questions': [
                    {
                        'prompt': 'Which exchanges are the main equity markets in India?',
                        'options': ['NYSE & NASDAQ', 'NSE & BSE', 'LSE & DAX', 'SGX & HKEX'],
                        'correct_index': 1,
                        'explanation': 'Retail Indian equities trade primarily on NSE and BSE.',
                    },
                    {
                        'prompt': 'What does a demat account hold?',
                        'options': ['Cash only', 'Shares electronically', 'Only mutual funds', 'Crypto tokens'],
                        'correct_index': 1,
                        'explanation': 'Demat accounts store securities in electronic form.',
                    },
                    {
                        'prompt': 'T+1 settlement means…',
                        'options': [
                            'Same-day settlement',
                            'Settlement one working day after trade',
                            'Settlement after one month',
                            'No settlement',
                        ],
                        'correct_index': 1,
                        'explanation': 'T+1 is one business day after the trade date.',
                    },
                    {
                        'prompt': 'A limit order lets you…',
                        'options': [
                            'Buy at any price instantly',
                            'Set your price and wait for a match',
                            'Avoid brokerage',
                            'Guarantee profit',
                        ],
                        'correct_index': 1,
                        'explanation': 'Limit orders execute at your price or better.',
                    },
                    {
                        'prompt': 'Best first step for a new investor?',
                        'options': [
                            'Max leverage in F&O',
                            'Learn basics and start small',
                            'Follow random social tips',
                            'All savings in one penny stock',
                        ],
                        'correct_index': 1,
                        'explanation': 'Education and small size reduce early mistakes.',
                    },
                ],
            },
            {
                'slug': 'quiz-risk',
                'title': 'Risk management quiz',
                'description': 'Position size, stops, and preservation.',
                'questions': [
                    {
                        'prompt': 'Risking 2% per trade refers to…',
                        'options': [
                            '2% of share price',
                            '2% of total trading capital at stop distance',
                            'Buying 2 shares',
                            'Doubling leverage',
                        ],
                        'correct_index': 1,
                        'explanation': 'Sizing ties risk to total capital.',
                    },
                    {
                        'prompt': 'A stop-loss should be set…',
                        'options': ['After a loss emotionally', 'Before entering', 'Only on Friday', 'Never'],
                        'correct_index': 1,
                        'explanation': 'Plan exits before entries.',
                    },
                    {
                        'prompt': 'Long option buyers typically max loss is…',
                        'options': ['Unlimited', 'Premium paid', 'Zero always', 'Index level'],
                        'correct_index': 1,
                        'explanation': 'Buyers risk the premium; sellers have different profiles.',
                    },
                ],
            },
            {
                'slug': 'quiz-ipo-mf',
                'title': 'IPO & mutual funds quiz',
                'description': 'SIP, NAV, and IPO application flow.',
                'questions': [
                    {
                        'prompt': 'SIP helps with…',
                        'options': ['Perfect market timing', 'Rupee cost averaging', 'Zero risk', 'Guaranteed returns'],
                        'correct_index': 1,
                        'explanation': 'Regular investing averages cost over time.',
                    },
                    {
                        'prompt': 'IPO application funds are blocked via…',
                        'options': ['Cash at exchange', 'UPI ASBA', 'Credit card', 'Cheque to company'],
                        'correct_index': 1,
                        'explanation': 'ASBA blocks bank funds until allotment.',
                    },
                    {
                        'prompt': 'Mutual fund NAV is…',
                        'options': ['One stock price', 'Per-unit fund value', 'Brokerage fee', 'Tax rate'],
                        'correct_index': 1,
                        'explanation': 'NAV is per-unit value of holdings.',
                    },
                ],
            },
        ],
    },
]

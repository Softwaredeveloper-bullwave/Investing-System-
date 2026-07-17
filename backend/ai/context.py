"""Build rich live context for the AI assistant — portfolio, stocks, app data."""

from __future__ import annotations

import re

from engagement.models import MarketIndex
from finance.goal_service import get_user_goals
from finance.models import Transaction, UserInvestment, Wallet
from kyc.models import KycProfile
from stocks.models import PriceAlert, SipPlan, Stock, StockHolding, WatchlistItem
from stocks.portfolio_service import get_stock_portfolio

from .app_knowledge import APP_KNOWLEDGE

_SYMBOL_RE = re.compile(r'\b[A-Z][A-Z0-9&.-]{1,19}\b')
_SKIP_WORDS = frozenset(
    {
        'AI', 'API', 'APP', 'BSE', 'BUY', 'ETF', 'FNO', 'GDP', 'GST', 'IPO', 'IT', 'KYC',
        'NSE', 'PE', 'P/E', 'PNL', 'P&L', 'RSI', 'SEBI', 'SIP', 'SMS', 'STT', 'TTS', 'UPI',
        'USD', 'WHY', 'HOW', 'THE', 'AND', 'FOR', 'MY', 'ME', 'ALL',
    }
)


def _inr(value) -> str:
    try:
        v = float(value)
    except (TypeError, ValueError):
        return '₹0'
    if abs(v) >= 10000000:
        return f'₹{v / 10000000:.2f} Cr'
    if abs(v) >= 100000:
        return f'₹{v / 100000:.2f} L'
    if abs(v) >= 1000:
        return f'₹{v / 1000:.1f}K'
    return f'₹{v:,.0f}'


def _message_intents(message: str) -> set[str]:
    m = (message or '').lower()
    intents: set[str] = {'summary'}
    if any(k in m for k in ('portfolio', 'holding', 'holdings', 'pnl', 'p&l', 'invested', 'my stock', 'my shares', 'performance', 'allocation')):
        intents.add('portfolio_detail')
    if any(k in m for k in ('wallet', 'balance', 'deposit', 'withdraw', 'cash')):
        intents.add('wallet')
    if any(k in m for k in ('goal', 'dream', 'retirement', 'education', 'marriage', 'vehicle', 'house')):
        intents.add('goals')
    if any(k in m for k in ('plan', 'featured', 'investment plan', 'monthly return', 'alpha', 'platinum')):
        intents.add('investments')
    if any(k in m for k in ('watchlist', 'watching', 'tracking')):
        intents.add('watchlist')
    if any(k in m for k in ('sip', 'systematic')):
        intents.add('sip')
    if any(k in m for k in ('alert', 'price alert')):
        intents.add('alerts')
    if any(k in m for k in ('app', 'bullwave', 'feature', 'how to', 'how do', 'where', 'navigate', 'use', 'kyc', 'fno', 'paper trade', 'commodit')):
        intents.add('app')
    if any(k in m for k in ('stock', 'share', 'nifty', 'banknifty', 'quote', 'ltp', 'price', 'buy', 'sell', 'view on', 'outlook', 'analysis')):
        intents.add('stocks')
    return intents


def extract_symbols(message: str, extra: str = '') -> list[str]:
    """Find likely NSE symbols in the user message."""
    text = f'{message} {extra}'.upper()
    candidates = [m.group(0) for m in _SYMBOL_RE.finditer(text) if m.group(0) not in _SKIP_WORDS]
    if not candidates:
        return []
    known = set(
        Stock.objects.filter(symbol__in=candidates).values_list('symbol', flat=True)
    )
    ordered: list[str] = []
    for sym in candidates:
        if sym in known and sym not in ordered:
            ordered.append(sym)
    return ordered[:6]


def _format_stock_block(stock: Stock) -> str:
    return (
        f"{stock.symbol} ({stock.name}, {stock.sector}): LTP {_inr(stock.ltp)} "
        f"({float(stock.change_percent):+.2f}% today), PE {float(stock.pe):.1f}, "
        f"52W {_inr(stock.week52_low)}–{_inr(stock.week52_high)}, "
        f"Vol {int(stock.volume):,}, MCap {_inr(stock.market_cap_cr)} Cr"
    )


def _user_label(user) -> str:
    name = (getattr(user, 'full_name', None) or getattr(user, 'name', None) or '').strip()
    if name:
        return name.split()[0]
    return 'User'


def build_user_context(user, message: str = '', symbol: str = '') -> str:
    """Assemble app knowledge + live user data for the LLM."""
    from finance.views import _build_portfolio

    intents = _message_intents(message)
    sections: list[str] = [APP_KNOWLEDGE.strip()]

    # ── Account snapshot (always) ──
    portfolio_totals = _build_portfolio(user, refresh_stocks=False)
    wallet, _ = Wallet.objects.get_or_create(user=user)
    account_lines = [
        f"USER: {_user_label(user)}",
        f"Wallet balance: {_inr(wallet.balance)}",
        f"Total portfolio value: {_inr(portfolio_totals['current_value'])} "
        f"(invested {_inr(portfolio_totals['total_investment'])}, "
        f"P&L {_inr(portfolio_totals['total_profit'])} / {float(portfolio_totals['growth_percent']):+.1f}%)",
        f"Day P&L: {_inr(portfolio_totals['day_pnl'])} ({float(portfolio_totals['day_pnl_percent']):+.2f}%)",
        f"Stock holdings count: {portfolio_totals['holdings_count']}",
    ]

    try:
        kyc = user.kyc_profile
        account_lines.append(f"KYC status: {kyc.overall_status}")
    except (KycProfile.DoesNotExist, AttributeError):
        account_lines.append('KYC status: not submitted')

    indices = MarketIndex.objects.all().order_by('id')[:5]
    if indices:
        account_lines.append(
            'Market: '
            + ', '.join(f'{i.short_name} {float(i.change_percent):+.2f}%' for i in indices)
        )
    sections.append('LIVE USER DATA\n' + '\n'.join(account_lines))

    # ── Stock portfolio detail ──
    if intents & {'portfolio_detail', 'stocks', 'summary'}:
        stock_pf = get_stock_portfolio(user, refresh='view' in message.lower() or 'latest' in message.lower())
        summary = stock_pf['summary']
        if summary['holdings_count']:
            pf_lines = [
                f"STOCK PORTFOLIO: invested {_inr(summary['total_invested'])}, "
                f"value {_inr(summary['current_value'])}, "
                f"total P&L {_inr(summary['total_pnl'])} ({summary['total_pnl_percent']:+.1f}%), "
                f"day {_inr(summary['day_pnl'])} ({summary['day_pnl_percent']:+.2f}%)",
            ]
            for row in stock_pf['holdings'][:12]:
                pf_lines.append(
                    f"  • {row['symbol']}: {row['quantity']} @ avg {_inr(row['avg_price'])}, "
                    f"LTP {_inr(row['ltp'])}, value {_inr(row['current_value'])}, "
                    f"P&L {_inr(row['pnl'])} ({row['pnl_percent']:+.1f}%)"
                )
            if stock_pf.get('sector_allocation'):
                sectors = ', '.join(
                    f"{s['label']} {s['percentage']:.0f}%"
                    for s in stock_pf['sector_allocation'][:5]
                )
                pf_lines.append(f"Sector allocation: {sectors}")
            sections.append('\n'.join(pf_lines))
        else:
            sections.append('STOCK PORTFOLIO: no stock holdings yet.')

    # ── Featured plan investments ──
    if intents & {'investments', 'portfolio_detail', 'summary'}:
        active = user.investments.filter(status=UserInvestment.Status.ACTIVE).select_related('plan')
        if active.exists():
            inv_lines = ['FEATURED PLAN INVESTMENTS:']
            for inv in active[:6]:
                inv_lines.append(
                    f"  • {inv.plan.name}: {_inr(inv.amount)} invested, "
                    f"monthly return {_inr(inv.monthly_return)}, ref {inv.reference_id}"
                )
            sections.append('\n'.join(inv_lines))

    # ── Goal plans ──
    if intents & {'goals', 'summary'}:
        goals = get_user_goals(user)
        active_goals = [g for g in goals if g.get('status') == 'active'][:5]
        if active_goals:
            goal_lines = ['GOAL PLANS:']
            for g in active_goals:
                goal_lines.append(
                    f"  • {g['title']}: saved {_inr(g['accumulated_amount'])} / "
                    f"target {_inr(g['target_amount'])} ({g['progress_percent']:.0f}%), "
                    f"{g['annual_return_rate']:.0f}% p.a., "
                    f"₹{float(g['monthly_contribution']):,.0f}/mo"
                )
            sections.append('\n'.join(goal_lines))

    # ── Watchlist ──
    if intents & {'watchlist', 'stocks', 'summary'}:
        watchlist = (
            WatchlistItem.objects.filter(user=user)
            .select_related('stock')
            .order_by('-added_at')[:10]
        )
        if watchlist:
            wl = ', '.join(
                f"{w.stock.symbol} {_inr(w.stock.ltp)} ({float(w.stock.change_percent):+.1f}%)"
                for w in watchlist
            )
            sections.append(f'WATCHLIST: {wl}')

    # ── SIP & alerts ──
    if intents & {'sip', 'summary'}:
        sips = SipPlan.objects.filter(user=user, is_active=True).select_related('stock')[:5]
        if sips:
            sip_lines = ['STOCK SIPs:']
            for s in sips:
                sip_lines.append(
                    f"  • {s.stock.symbol}: {_inr(s.monthly_amount)}/mo, "
                    f"{s.installments_done}/{s.total_installments} done, value {_inr(s.current_value)}"
                )
            sections.append('\n'.join(sip_lines))

    if intents & {'alerts', 'summary'}:
        alerts = PriceAlert.objects.filter(user=user, is_active=True).select_related('stock')[:5]
        if alerts:
            alert_lines = ['PRICE ALERTS:']
            for a in alerts:
                alert_lines.append(
                    f"  • {a.stock.symbol} {a.condition} {_inr(a.target_price)}"
                )
            sections.append('\n'.join(alert_lines))

    # ── Stock quotes (from message / explicit symbol) ──
    symbols = extract_symbols(message, symbol)
    if symbol.strip():
        sym = symbol.strip().upper()
        if sym not in symbols:
            symbols.insert(0, sym)

    if symbols:
        stock_blocks = []
        for sym in symbols:
            stock = Stock.objects.filter(symbol__iexact=sym).first()
            if stock:
                holding = StockHolding.objects.filter(user=user, stock=stock, quantity__gt=0).first()
                block = _format_stock_block(stock)
                if holding:
                    invested = float(holding.quantity) * float(holding.avg_price)
                    current = float(holding.quantity) * float(stock.ltp)
                    pnl = current - invested
                    block += (
                        f" | USER OWNS {holding.quantity} @ avg {_inr(holding.avg_price)}, "
                        f"P&L {_inr(pnl)}"
                    )
                stock_blocks.append(block)
        if stock_blocks:
            sections.append('STOCK QUOTES REQUESTED\n' + '\n'.join(stock_blocks))

    # ── Recent activity (wallet/trades) ──
    if intents & {'wallet', 'portfolio_detail'}:
        recent = user.transactions.order_by('-created_at')[:5]
        if recent:
            tx_lines = ['RECENT TRANSACTIONS:']
            for tx in recent:
                tx_lines.append(
                    f"  • {tx.type} {_inr(tx.amount)} — {tx.description or tx.reference_id}"
                )
            sections.append('\n'.join(tx_lines))

    return '\n\n---\n\n'.join(sections)

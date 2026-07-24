"""Unified Paper Portfolio — combines equity, option, and commodity paper
positions into a single live view, all sharing the same `PaperWallet`. This
is the "one full simulated trading account" summary: total virtual buying
power, total mark-to-market equity, and unrealized P&L broken down by asset
class and rolled up into one number.

Equity holdings/P&L are already live (`portfolio_service.get_stock_portfolio`
prices every `StockHolding` off `Stock.ltp`). Option holdings are marked at
a live estimated premium (`paper_option_service._holding_payload`, backed by
`options_service.estimate_option_premium`). Commodity holdings are marked at
a live USD quote (`paper_commodity_service.list_paper_commodity_holdings`).
"""

from __future__ import annotations

from .paper_commodity_service import list_paper_commodity_holdings
from .paper_option_service import list_paper_option_holdings
from .portfolio_service import get_stock_portfolio


def _round2(value) -> float:
    return round(float(value), 2)


def get_unified_paper_portfolio(user) -> dict:
    stock_portfolio = get_stock_portfolio(user)
    stock_summary = stock_portfolio['summary']
    stock_holdings = stock_portfolio['holdings']

    option_holdings = list_paper_option_holdings(user)
    option_value = 0.0
    option_pnl = 0.0
    option_cost = 0.0
    for h in option_holdings:
        cost = h['avgPremium'] * h['quantity'] * h['lotSize']
        value = h.get('currentValueInr', cost)
        option_cost += cost
        option_value += value
        option_pnl += h.get('unrealizedPnlInr', 0.0)

    commodity_holdings = list_paper_commodity_holdings(user)
    commodity_value = sum(h['currentValueInr'] for h in commodity_holdings)
    commodity_cost = sum(h['investedInr'] for h in commodity_holdings)
    commodity_pnl = sum(h['pnlInr'] for h in commodity_holdings)

    total_invested = stock_summary['total_invested'] + option_cost + commodity_cost
    total_current_value = stock_summary['current_value'] + option_value + commodity_value
    total_unrealized_pnl = stock_summary['total_pnl'] + option_pnl + commodity_pnl

    virtual_balance = stock_summary['virtual_balance']
    virtual_starting_balance = stock_summary['virtual_starting_balance']
    total_equity = virtual_balance + total_current_value
    total_return_percent = (
        (total_equity - virtual_starting_balance) / virtual_starting_balance * 100
        if virtual_starting_balance else 0.0
    )

    return {
        'virtual_balance': _round2(virtual_balance),
        'virtual_starting_balance': _round2(virtual_starting_balance),
        'total_invested': _round2(total_invested),
        'total_current_value': _round2(total_current_value),
        'total_unrealized_pnl': _round2(total_unrealized_pnl),
        'total_unrealized_pnl_percent': _round2(
            (total_unrealized_pnl / total_invested * 100) if total_invested else 0.0
        ),
        'total_equity': _round2(total_equity),
        'total_return_percent': _round2(total_return_percent),
        'equity': {
            'holdings': stock_holdings,
            'invested': _round2(stock_summary['total_invested']),
            'current_value': _round2(stock_summary['current_value']),
            'unrealized_pnl': _round2(stock_summary['total_pnl']),
            'count': len(stock_holdings),
        },
        'options': {
            'holdings': option_holdings,
            'invested': _round2(option_cost),
            'current_value': _round2(option_value),
            'unrealized_pnl': _round2(option_pnl),
            'count': len(option_holdings),
        },
        'commodities': {
            'holdings': commodity_holdings,
            'invested': _round2(commodity_cost),
            'current_value': _round2(commodity_value),
            'unrealized_pnl': _round2(commodity_pnl),
            'count': len(commodity_holdings),
        },
    }

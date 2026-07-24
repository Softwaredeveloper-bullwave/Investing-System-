"""Estimated equity-delivery trading charges for paper orders.

Purely educational — modelled on typical Indian discount-broker delivery
charge structures so the simulation teaches realistic net-of-charges P&L
instead of pretending trading is free. All amounts are Decimal end to end.
"""

from __future__ import annotations

from decimal import ROUND_HALF_UP, Decimal

# Delivery equity charge rates (illustrative, discount-broker style).
BROKERAGE_FLAT = Decimal('0')                    # Most discount brokers: ₹0 delivery brokerage.
STT_RATE = Decimal('0.001')                       # 0.1% on both buy and sell (delivery).
EXCHANGE_TXN_RATE = Decimal('0.0000297')          # NSE exchange transaction charge.
SEBI_RATE = Decimal('0.0000010')                  # ₹10 per crore.
STAMP_DUTY_RATE = Decimal('0.00015')              # 0.015%, buy side only.
GST_RATE = Decimal('0.18')                        # 18% on (brokerage + exchange txn charge).


def _round2(value: Decimal) -> Decimal:
    return value.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)


def estimate_charges(*, side: str, order_value: Decimal) -> dict:
    """Returns a full charges breakdown for one fill leg (one buy or one sell).

    `order_value` = quantity * fill price, as a Decimal.
    """
    side = (side or '').upper()
    order_value = Decimal(order_value)

    brokerage = BROKERAGE_FLAT
    stt = order_value * STT_RATE
    exchange_txn = order_value * EXCHANGE_TXN_RATE
    sebi_charges = order_value * SEBI_RATE
    stamp_duty = order_value * STAMP_DUTY_RATE if side == 'BUY' else Decimal('0')
    gst = (brokerage + exchange_txn) * GST_RATE

    total = brokerage + stt + exchange_txn + sebi_charges + stamp_duty + gst
    total = _round2(total)

    return {
        'brokerage': _round2(brokerage),
        'stt': _round2(stt),
        'exchange_txn_charge': _round2(exchange_txn),
        'sebi_charges': _round2(sebi_charges),
        'stamp_duty': _round2(stamp_duty),
        'gst': _round2(gst),
        'total_charges': total,
    }


def total_charges(*, side: str, order_value: Decimal) -> Decimal:
    return estimate_charges(side=side, order_value=order_value)['total_charges']

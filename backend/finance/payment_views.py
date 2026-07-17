import uuid
from decimal import Decimal

from django.conf import settings
from django.db import transaction
from django.utils import timezone
from rest_framework import serializers, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from core.integrations.razorpay_service import (
    RazorpayError,
    create_order,
    is_configured,
    verify_payment_signature,
    verify_webhook_signature,
)
from core.serializers import CamelCaseSerializer
from engagement.models import Notification

from .models import PaymentOrder, Wallet, WalletTransaction


class CreateDepositOrderSerializer(CamelCaseSerializer):
    amount = serializers.DecimalField(max_digits=14, decimal_places=2, min_value=1)


class VerifyDepositSerializer(CamelCaseSerializer):
    order_id = serializers.CharField()
    payment_id = serializers.CharField()
    signature = serializers.CharField()


class CreateDepositOrderView(APIView):
    """Create Razorpay order for wallet deposit."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        if not is_configured():
            return Response(
                {
                    'detail': 'Razorpay is not configured. Add RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET to .env.',
                    'devMode': settings.DEBUG,
                },
                status=503,
            )

        serializer = CreateDepositOrderSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        amount = serializer.validated_data['amount']

        try:
            order = create_order(amount)
        except RazorpayError as exc:
            return Response({'detail': str(exc)}, status=503)

        PaymentOrder.objects.create(
            user=request.user,
            order_id=order['order_id'],
            amount=amount,
            currency=order['currency'],
        )

        return Response(
            {
                'orderId': order['order_id'],
                'amount': float(order['amount']),
                'amountPaise': order['amount_paise'],
                'currency': order['currency'],
                'keyId': order['key_id'],
            }
        )


class VerifyDepositView(APIView):
    """Verify Razorpay payment and credit wallet."""

    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):
        serializer = VerifyDepositSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        order_id = serializer.validated_data['order_id']
        payment_id = serializer.validated_data['payment_id']
        signature = serializer.validated_data['signature']

        if not verify_payment_signature(order_id, payment_id, signature):
            return Response({'detail': 'Invalid payment signature.'}, status=400)

        try:
            payment_order = PaymentOrder.objects.select_for_update().get(
                user=request.user, order_id=order_id, status=PaymentOrder.Status.CREATED
            )
        except PaymentOrder.DoesNotExist:
            return Response({'detail': 'Payment order not found or already processed.'}, status=404)

        wallet = Wallet.objects.select_for_update().get(user=request.user)
        WalletTransaction.objects.create(
            wallet=wallet,
            type=WalletTransaction.TxType.DEPOSIT,
            amount=payment_order.amount,
            status=WalletTransaction.Status.COMPLETED,
        )
        wallet.balance += payment_order.amount
        wallet.save(update_fields=['balance'])

        payment_order.payment_id = payment_id
        payment_order.status = PaymentOrder.Status.PAID
        payment_order.paid_at = timezone.now()
        payment_order.save()

        Notification.objects.create(
            user=request.user,
            title='Deposit Successful',
            message=f'₹{payment_order.amount:,.0f} added to your wallet.',
            type='wallet',
        )

        return Response({'success': True, 'balance': float(wallet.balance)})


class RazorpayWebhookView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    @transaction.atomic
    def post(self, request):
        signature = request.headers.get('X-Razorpay-Signature', '')
        if not verify_webhook_signature(request.body, signature):
            return Response({'detail': 'Invalid webhook signature.'}, status=400)

        event = request.data.get('event', '')
        payload = request.data.get('payload', {})
        if event != 'payment.captured':
            return Response({'status': 'ignored'})

        payment_entity = payload.get('payment', {}).get('entity', {})
        order_id = payment_entity.get('order_id')
        payment_id = payment_entity.get('id')
        amount_paise = payment_entity.get('amount', 0)

        if not order_id:
            return Response({'status': 'no_order'})

        try:
            payment_order = PaymentOrder.objects.select_for_update().get(
                order_id=order_id, status=PaymentOrder.Status.CREATED
            )
        except PaymentOrder.DoesNotExist:
            return Response({'status': 'already_processed'})

        amount = Decimal(str(amount_paise)) / Decimal('100')
        wallet = Wallet.objects.select_for_update().get(user=payment_order.user)
        WalletTransaction.objects.create(
            wallet=wallet,
            type=WalletTransaction.TxType.DEPOSIT,
            amount=amount,
            status=WalletTransaction.Status.COMPLETED,
        )
        wallet.balance += amount
        wallet.save(update_fields=['balance'])

        payment_order.payment_id = payment_id or ''
        payment_order.status = PaymentOrder.Status.PAID
        payment_order.paid_at = timezone.now()
        payment_order.save()

        return Response({'status': 'ok'})

import json
import logging
import uuid
from decimal import Decimal

from django.conf import settings
from django.db import transaction
from django.utils import timezone
from rest_framework import serializers, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from core.serializers import CamelCaseSerializer
from engagement.models import Notification
from finance.models import PaymentOrder, Transaction, Wallet, WalletTransaction
from kyc.models import KycProfile
from kyc.service import get_or_create_profile
from services.providers.cashfree_payments import CashfreePaymentError, create_payment_order, verify_payment_webhook
from services.providers.cashfree_payouts import CashfreePayoutError, initiate_payout, verify_payout_webhook

from .models import PayoutRecord

logger = logging.getLogger('bullwave.payments')


class CreatePaymentSerializer(CamelCaseSerializer):
    amount = serializers.DecimalField(max_digits=14, decimal_places=2, min_value=1)
    return_url = serializers.URLField(required=False, allow_blank=True)


class WithdrawSerializer(CamelCaseSerializer):
    amount = serializers.DecimalField(max_digits=14, decimal_places=2, min_value=1)


class CreatePaymentView(APIView):
    """Create Cashfree payment order for wallet deposit."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = CreatePaymentSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        amount = serializer.validated_data['amount']
        return_url = serializer.validated_data.get('return_url', '')

        user = request.user
        try:
            order = create_payment_order(
                amount_inr=amount,
                customer_id=str(user.id),
                customer_phone=user.phone,
                customer_email=user.email,
                return_url=return_url,
            )
        except CashfreePaymentError as exc:
            from services.providers.cashfree_config import cashfree_settings
            if settings.DEBUG and not cashfree_settings().is_configured:
                return self._dev_instant_deposit(request, amount)
            return Response({'detail': str(exc)}, status=503)

        PaymentOrder.objects.create(
            user=user,
            gateway='cashfree',
            order_id=order['order_id'],
            amount=amount,
            currency='INR',
        )

        return Response(
            {
                'orderId': order['order_id'],
                'paymentSessionId': order['payment_session_id'],
                'amount': order['order_amount'],
                'currency': order['order_currency'],
                'environment': order['environment'],
            }
        )

    @transaction.atomic
    def _dev_instant_deposit(self, request, amount):
        wallet = Wallet.objects.select_for_update().get(user=request.user)
        WalletTransaction.objects.create(
            wallet=wallet,
            type=WalletTransaction.TxType.DEPOSIT,
            amount=amount,
            status=WalletTransaction.Status.COMPLETED,
        )
        wallet.balance += amount
        wallet.save(update_fields=['balance'])
        return Response(
            {
                'devMode': True,
                'success': True,
                'balance': float(wallet.balance),
                'message': 'Dev instant deposit (configure Cashfree for production).',
            }
        )


class PaymentWebhookView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    @transaction.atomic
    def post(self, request):
        signature = request.headers.get('x-webhook-signature', '')
        timestamp = request.headers.get('x-webhook-timestamp', '')
        raw = request.body

        if not verify_payment_webhook(raw, signature, timestamp):
            return Response({'detail': 'Invalid webhook signature.'}, status=400)

        try:
            payload = json.loads(raw.decode('utf-8'))
        except json.JSONDecodeError:
            return Response({'detail': 'Invalid JSON.'}, status=400)

        event_type = payload.get('type', '')
        data = payload.get('data', {})
        order = data.get('order', {}) or data
        order_id = order.get('order_id') or data.get('order_id')
        payment_status = (order.get('order_status') or data.get('payment_status') or '').upper()

        if not order_id:
            return Response({'status': 'ignored'})

        if payment_status not in ('PAID', 'SUCCESS', 'ACTIVE'):
            return Response({'status': 'ignored_status'})

        try:
            payment_order = PaymentOrder.objects.select_for_update().get(
                order_id=order_id, status=PaymentOrder.Status.CREATED
            )
        except PaymentOrder.DoesNotExist:
            return Response({'status': 'already_processed'})

        wallet = Wallet.objects.select_for_update().get(user=payment_order.user)
        WalletTransaction.objects.create(
            wallet=wallet,
            type=WalletTransaction.TxType.DEPOSIT,
            amount=payment_order.amount,
            status=WalletTransaction.Status.COMPLETED,
        )
        wallet.balance += payment_order.amount
        wallet.save(update_fields=['balance'])

        payment_order.payment_id = data.get('cf_payment_id', '') or data.get('payment_id', '')
        payment_order.status = PaymentOrder.Status.PAID
        payment_order.paid_at = timezone.now()
        payment_order.save()

        Notification.objects.create(
            user=payment_order.user,
            title='Deposit Successful',
            message=f'₹{payment_order.amount:,.0f} added to your wallet.',
            type='wallet',
        )
        return Response({'status': 'ok'})


class WithdrawView(APIView):
    """Initiate withdrawal via Cashfree Payouts to verified bank account."""

    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):
        serializer = WithdrawSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        amount = serializer.validated_data['amount']
        user = request.user

        profile = get_or_create_profile(user)
        if profile.overall_status != KycProfile.OverallStatus.VERIFIED:
            return Response(
                {'detail': 'Complete KYC verification before withdrawing.'},
                status=403,
            )

        wallet = Wallet.objects.select_for_update().get(user=user)
        if wallet.balance < amount:
            return Response({'detail': 'Insufficient wallet balance.'}, status=400)

        ref_id = f'BW-WD-{timezone.now().strftime("%Y")}-{uuid.uuid4().hex[:6].upper()}'

        wallet.balance -= amount
        wallet.save(update_fields=['balance'])

        WalletTransaction.objects.create(
            wallet=wallet,
            type=WalletTransaction.TxType.WITHDRAWAL,
            amount=amount,
            status=WalletTransaction.Status.PENDING,
        )
        Transaction.objects.create(
            user=user,
            reference_id=ref_id,
            type=Transaction.TxType.WITHDRAWAL,
            status=Transaction.Status.PENDING,
            amount=amount,
            description='Withdrawal to bank account',
        )

        payout_status = PayoutRecord.Status.SUBMITTED
        payout_ref = ''
        failure = ''

        try:
            result = initiate_payout(
                amount=float(amount),
                account_holder_name=profile.account_holder_name,
                account_number=profile.bank_account_number,
                ifsc=profile.bank_ifsc,
                phone=user.phone,
                transfer_id=ref_id,
            )
            payout_status = {
                'SUCCESS': PayoutRecord.Status.COMPLETED,
                'COMPLETED': PayoutRecord.Status.COMPLETED,
                'PENDING': PayoutRecord.Status.PROCESSING,
                'PROCESSING': PayoutRecord.Status.PROCESSING,
            }.get(result['status'], PayoutRecord.Status.PROCESSING)
            payout_ref = result.get('reference_id', '')
        except CashfreePayoutError as exc:
            payout_status = PayoutRecord.Status.PROCESSING if settings.DEBUG else PayoutRecord.Status.FAILED
            failure = str(exc)
            if not settings.DEBUG:
                wallet.balance += amount
                wallet.save(update_fields=['balance'])
                return Response({'detail': str(exc)}, status=503)

        payout = PayoutRecord.objects.create(
            user=user,
            transfer_id=ref_id,
            reference_id=payout_ref,
            amount=amount,
            status=payout_status,
            failure_reason=failure,
        )

        if payout_status == PayoutRecord.Status.COMPLETED:
            WalletTransaction.objects.filter(
                wallet=wallet, type=WalletTransaction.TxType.WITHDRAWAL, status=WalletTransaction.Status.PENDING
            ).order_by('-created_at').first()
            wt = wallet.transactions.filter(type=WalletTransaction.TxType.WITHDRAWAL).first()
            if wt:
                wt.status = WalletTransaction.Status.COMPLETED
                wt.save(update_fields=['status'])
            Transaction.objects.filter(user=user, reference_id=ref_id).update(status=Transaction.Status.COMPLETED)
            payout.completed_at = timezone.now()
            payout.save(update_fields=['completed_at'])

        Notification.objects.create(
            user=user,
            title='Withdrawal Submitted',
            message=f'₹{amount:,.0f} withdrawal is {payout_status}.',
            type='wallet',
        )

        return Response(
            {
                'success': True,
                'referenceId': ref_id,
                'payoutId': str(payout.id),
                'status': payout_status,
                'balance': float(wallet.balance),
            }
        )


class PayoutWebhookView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    @transaction.atomic
    def post(self, request):
        signature = request.headers.get('x-webhook-signature', '') or request.headers.get('X-Webhook-Signature', '')
        if not verify_payout_webhook(request.body, signature):
            return Response({'detail': 'Invalid webhook signature.'}, status=400)

        payload = request.data
        transfer_id = payload.get('transferId') or payload.get('transfer_id')
        payout_status = (payload.get('status') or payload.get('event') or '').upper()

        if not transfer_id:
            return Response({'status': 'ignored'})

        try:
            payout = PayoutRecord.objects.select_for_update().get(transfer_id=transfer_id)
        except PayoutRecord.DoesNotExist:
            return Response({'status': 'not_found'})

        if payout_status in ('SUCCESS', 'COMPLETED'):
            payout.status = PayoutRecord.Status.COMPLETED
            payout.completed_at = timezone.now()
            Transaction.objects.filter(user=payout.user, reference_id=transfer_id).update(
                status=Transaction.Status.COMPLETED
            )
            WalletTransaction.objects.filter(
                wallet__user=payout.user,
                type=WalletTransaction.TxType.WITHDRAWAL,
                status=WalletTransaction.Status.PENDING,
            ).update(status=WalletTransaction.Status.COMPLETED)
        elif payout_status in ('FAILED', 'REJECTED', 'REVERSED'):
            payout.status = PayoutRecord.Status.FAILED
            payout.failure_reason = payload.get('reason', 'Payout failed')[:280]
            wallet = Wallet.objects.select_for_update().get(user=payout.user)
            wallet.balance += payout.amount
            wallet.save(update_fields=['balance'])
            Transaction.objects.filter(user=payout.user, reference_id=transfer_id).update(
                status=Transaction.Status.FAILED
            )

        payout.raw_response = payload if isinstance(payload, dict) else {}
        payout.save()
        return Response({'status': 'ok'})


class PaymentStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, order_id):
        try:
            order = PaymentOrder.objects.get(user=request.user, order_id=order_id)
        except PaymentOrder.DoesNotExist:
            return Response({'detail': 'Order not found.'}, status=404)
        return Response(
            {
                'orderId': order.order_id,
                'status': order.status,
                'amount': float(order.amount),
                'paidAt': order.paid_at.isoformat() if order.paid_at else None,
            }
        )

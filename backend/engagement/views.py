from decimal import Decimal



from django.conf import settings

from django.db.models import Sum

from rest_framework.permissions import AllowAny, IsAuthenticated

from rest_framework.response import Response

from rest_framework.views import APIView



from .models import Notification, ReferralReward, SupportFaq, SupportTicket

from .referral_service import (

    apply_referral_code,

    build_share_message,

    credit_referral_reward,

    referral_reward_amount,

)

from .serializers import (

    ApplyReferralSerializer,

    CreateTicketSerializer,

    NotificationSerializer,

    ReferralSerializer,

    SupportFaqSerializer,

    SupportTicketSerializer,

)





class NotificationListView(APIView):

    permission_classes = [IsAuthenticated]



    def get(self, request):

        return Response(NotificationSerializer(request.user.notifications.all(), many=True).data)





class NotificationReadView(APIView):

    permission_classes = [IsAuthenticated]



    def patch(self, request, notification_id):

        try:

            notif = request.user.notifications.get(pk=notification_id)

        except Notification.DoesNotExist:

            return Response({'detail': 'Not found.'}, status=404)

        notif.is_read = True

        notif.save(update_fields=['is_read'])

        return Response(NotificationSerializer(notif).data)





class NotificationMarkAllReadView(APIView):

    permission_classes = [IsAuthenticated]



    def post(self, request):

        request.user.notifications.filter(is_read=False).update(is_read=True)

        return Response({'success': True})





class SupportFaqListView(APIView):

    permission_classes = [AllowAny]



    def get(self, request):

        return Response(SupportFaqSerializer(SupportFaq.objects.all(), many=True).data)





class SupportTicketListView(APIView):

    permission_classes = [IsAuthenticated]



    def get(self, request):

        return Response(SupportTicketSerializer(request.user.support_tickets.all(), many=True).data)



    def post(self, request):

        serializer = CreateTicketSerializer(data=request.data)

        serializer.is_valid(raise_exception=True)

        ticket = SupportTicket.objects.create(

            user=request.user,

            subject=serializer.validated_data['subject'],

            message=serializer.validated_data.get('message', ''),

        )

        return Response(SupportTicketSerializer(ticket).data, status=201)





class ReferralView(APIView):

    permission_classes = [IsAuthenticated]



    def get(self, request):

        user = request.user

        rewards = user.referral_rewards.all()

        total_rewards = rewards.aggregate(t=Sum('amount'))['t'] or Decimal('0')

        reward_per = referral_reward_amount()



        referred_friends = []

        for friend in user.referrals.all().order_by('-date_joined'):

            rewarded = ReferralReward.objects.filter(referred_user=friend).exists()

            if rewarded:

                status = 'rewarded'

            elif friend.has_completed_onboarding:

                status = 'completed'

            else:

                status = 'pending'

            referred_friends.append(

                {

                    'name': friend.name or friend.phone,

                    'joined_at': friend.date_joined,

                    'status': status,

                }

            )



        applied_code = ''

        if user.referred_by_id:

            applied_code = user.referred_by.referral_code



        return Response(

            ReferralSerializer(

                {

                    'code': user.referral_code,

                    'total_referrals': user.referrals.filter(has_completed_onboarding=True).count(),

                    'pending_referrals': user.referrals.filter(has_completed_onboarding=False).count(),

                    'total_rewards': total_rewards,

                    'reward_per_referral': reward_per,

                    'share_message': build_share_message(user),

                    'has_applied_referral': bool(user.referred_by_id),

                    'applied_referral_code': applied_code,

                    'rewards_history': rewards,

                    'referred_friends': referred_friends,

                }

            ).data

        )





class ApplyReferralView(APIView):

    permission_classes = [IsAuthenticated]



    def post(self, request):

        serializer = ApplyReferralSerializer(data=request.data)

        serializer.is_valid(raise_exception=True)



        ok, message = apply_referral_code(request.user, serializer.validated_data['code'])

        if not ok:

            return Response({'detail': message}, status=400)



        rewarded = False

        if request.user.has_completed_onboarding:

            rewarded = credit_referral_reward(request.user)



        reward_amount = float(referral_reward_amount())

        return Response(

            {

                'success': True,

                'message': message,

                'rewardCreditedToFriend': rewarded,

                'rewardPerReferral': reward_amount,

            }

        )


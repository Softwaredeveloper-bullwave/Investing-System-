from rest_framework import serializers

from core.serializers import CamelCaseModelSerializer, CamelCaseSerializer
from .models import MarketIndex, MarketNews, Notification, ReferralReward, SupportFaq, SupportTicket


class MarketIndexSerializer(CamelCaseModelSerializer):
    class Meta:
        model = MarketIndex
        fields = ('id', 'name', 'short_name', 'value', 'change', 'change_percent')


class MarketNewsSerializer(CamelCaseModelSerializer):
    class Meta:
        model = MarketNews
        fields = ('title', 'subtitle')


class NotificationSerializer(CamelCaseModelSerializer):
    date = serializers.DateTimeField(source='created_at')

    class Meta:
        model = Notification
        fields = ('id', 'title', 'message', 'date', 'is_read', 'type')


class SupportFaqSerializer(CamelCaseModelSerializer):
    class Meta:
        model = SupportFaq
        fields = ('question', 'answer')


class SupportTicketSerializer(CamelCaseModelSerializer):
    created_at = serializers.DateTimeField()

    class Meta:
        model = SupportTicket
        fields = ('id', 'subject', 'status', 'created_at')


class CreateTicketSerializer(CamelCaseSerializer):
    subject = serializers.CharField(max_length=200)
    message = serializers.CharField(required=False, allow_blank=True)


class ReferralRewardSerializer(CamelCaseModelSerializer):
    friend_name = serializers.CharField()
    date = serializers.DateTimeField(source='created_at')

    class Meta:
        model = ReferralReward
        fields = ('friend_name', 'amount', 'date')


class ReferredFriendSerializer(CamelCaseSerializer):
    name = serializers.CharField()
    joined_at = serializers.DateTimeField()
    status = serializers.CharField()

    def to_representation(self, instance):
        joined = instance['joined_at']
        return {
            'name': instance['name'],
            'joinedAt': joined.isoformat() if hasattr(joined, 'isoformat') else joined,
            'status': instance['status'],
        }


class ReferralSerializer(CamelCaseSerializer):
    code = serializers.CharField()
    total_referrals = serializers.IntegerField()
    pending_referrals = serializers.IntegerField()
    total_rewards = serializers.DecimalField(max_digits=12, decimal_places=2)
    reward_per_referral = serializers.DecimalField(max_digits=12, decimal_places=2)
    share_message = serializers.CharField()
    has_applied_referral = serializers.BooleanField()
    applied_referral_code = serializers.CharField()
    rewards_history = ReferralRewardSerializer(many=True)
    referred_friends = ReferredFriendSerializer(many=True)

    def to_representation(self, instance):
        return {
            'code': instance['code'],
            'totalReferrals': instance['total_referrals'],
            'pendingReferrals': instance['pending_referrals'],
            'totalRewards': float(instance['total_rewards']),
            'rewardPerReferral': float(instance['reward_per_referral']),
            'shareMessage': instance['share_message'],
            'hasAppliedReferral': instance['has_applied_referral'],
            'appliedReferralCode': instance['applied_referral_code'],
            'rewardsHistory': ReferralRewardSerializer(instance['rewards_history'], many=True).data,
            'referredFriends': ReferredFriendSerializer(instance['referred_friends'], many=True).data,
        }


class ApplyReferralSerializer(CamelCaseSerializer):
    code = serializers.CharField(max_length=20)

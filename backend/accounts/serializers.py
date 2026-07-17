from rest_framework import serializers

from core.serializers import CamelCaseModelSerializer, CamelCaseSerializer
from .models import BankAccount, KycDocument, User


class UserSerializer(CamelCaseModelSerializer):
    pan_status = serializers.SerializerMethodField()
    kyc_status = serializers.SerializerMethodField()
    avatar_url = serializers.SerializerMethodField()
    date_of_birth = serializers.DateField(required=False, allow_null=True)

    class Meta:
        model = User
        fields = (
            'id', 'name', 'phone', 'email', 'pan_status', 'kyc_status',
            'avatar_url', 'date_of_birth', 'city', 'bio',
            'referral_code', 'has_completed_onboarding',
        )
        read_only_fields = ('id', 'phone', 'referral_code', 'pan_status', 'kyc_status')

    def get_avatar_url(self, obj):
        if obj.avatar:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.avatar.url)
            return obj.avatar.url
        return obj.avatar_url or ''

    def get_pan_status(self, obj):
        if obj.pan_status == 'verified':
            return obj.get_pan_status_display()
        return obj.pan_status.replace('_', ' ').title()

    def get_kyc_status(self, obj):
        mapping = {
            'not_submitted': 'Not Submitted',
            'pending': 'Pending',
            'verified': 'Verified',
            'rejected': 'Rejected',
            'in_progress': 'In Progress',
            'completed': 'Completed',
        }
        return mapping.get(obj.kyc_status, obj.kyc_status)


class ProfileUpdateSerializer(CamelCaseSerializer):
    name = serializers.CharField(max_length=120, required=False, allow_blank=True)
    email = serializers.EmailField(required=False, allow_blank=True)
    city = serializers.CharField(max_length=80, required=False, allow_blank=True)
    bio = serializers.CharField(max_length=280, required=False, allow_blank=True)
    date_of_birth = serializers.DateField(required=False, allow_null=True)


class CompleteProfileSerializer(CamelCaseSerializer):
    name = serializers.CharField(max_length=120, min_length=2)
    email = serializers.EmailField(required=False, allow_blank=True)
    city = serializers.CharField(max_length=80, required=False, allow_blank=True)
    bio = serializers.CharField(max_length=280, required=False, allow_blank=True)
    date_of_birth = serializers.DateField(required=False, allow_null=True)
    referral_code = serializers.CharField(max_length=20, required=False, allow_blank=True)


class BankAccountSerializer(CamelCaseModelSerializer):
    masked_account_number = serializers.SerializerMethodField()

    class Meta:
        model = BankAccount
        fields = (
            'account_holder_name', 'bank_name', 'account_number', 'masked_account_number',
            'ifsc', 'pan_number', 'is_verified', 'verification_status',
            'name_at_bank', 'name_match_result', 'pan_registered_name',
            'verification_message', 'verified_at',
        )
        read_only_fields = (
            'is_verified', 'verification_status', 'name_at_bank',
            'name_match_result', 'pan_registered_name', 'verification_message', 'verified_at',
        )
        extra_kwargs = {
            'account_number': {'write_only': True},
        }

    def get_masked_account_number(self, obj):
        acct = obj.account_number or ''
        if len(acct) <= 4:
            return acct
        return f'****{acct[-4:]}'


class KycDocumentSerializer(CamelCaseModelSerializer):
    class Meta:
        model = KycDocument
        fields = ('document_type', 'file', 'status', 'uploaded_at')
        read_only_fields = ('status', 'uploaded_at')


class KycStatusSerializer(CamelCaseSerializer):
    kyc_status = serializers.CharField()
    pan_status = serializers.CharField()
    uploaded_documents = serializers.ListField(child=serializers.CharField())

    def to_representation(self, instance):
        mapping = {
            'pending': 'Pending',
            'in_progress': 'In Progress',
            'completed': 'Completed',
            'rejected': 'Rejected',
        }
        return {
            'kycStatus': mapping.get(instance.kyc_status, instance.kyc_status),
            'panStatus': instance.get_pan_status_display(),
            'uploadedDocuments': list(
                instance.kyc_documents.values_list('document_type', flat=True)
            ),
        }

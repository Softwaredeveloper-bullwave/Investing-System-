from rest_framework import serializers

from core.serializers import CamelCaseSerializer

from .models import KycProfile, VerificationAuditLog


class VerifyPanSerializer(CamelCaseSerializer):
    pan_number = serializers.CharField(max_length=10, min_length=10)
    holder_name = serializers.CharField(max_length=120, required=False, allow_blank=True)


class VerifyBankSerializer(CamelCaseSerializer):
    account_holder_name = serializers.CharField(max_length=120, min_length=3)
    account_number = serializers.CharField(max_length=20, min_length=9)
    confirm_account_number = serializers.CharField(max_length=20, min_length=9)
    ifsc = serializers.CharField(max_length=11, min_length=11)


class KycStatusSerializer(CamelCaseSerializer):
    mobile_verified = serializers.BooleanField()
    pan_verified = serializers.BooleanField()
    bank_verified = serializers.BooleanField()
    name_match_passed = serializers.BooleanField()
    overall_status = serializers.CharField()
    pan_number_masked = serializers.CharField()
    pan_name = serializers.CharField()
    pan_status = serializers.CharField()
    bank_name = serializers.CharField()
    bank_branch = serializers.CharField()
    account_holder_name = serializers.CharField()
    bank_account_masked = serializers.CharField()
    ifsc = serializers.CharField()
    bank_status = serializers.CharField()
    name_at_bank = serializers.CharField()
    name_match_result = serializers.CharField()
    name_match_score = serializers.FloatField()
    verified_at = serializers.CharField(allow_null=True)

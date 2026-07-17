from rest_framework import serializers

from .models import GoalPlanTemplate, UserGoalPlan


class GoalPlanTemplateSerializer(serializers.ModelSerializer):
    min_target = serializers.DecimalField(max_digits=14, decimal_places=2, coerce_to_string=False)
    suggested_monthly = serializers.DecimalField(max_digits=14, decimal_places=2, coerce_to_string=False)

    class Meta:
        model = GoalPlanTemplate
        fields = (
            'id', 'category', 'name', 'tagline', 'icon', 'color',
            'min_target', 'suggested_monthly', 'min_duration_months', 'max_duration_months',
        )


class CreateGoalSerializer(serializers.Serializer):
    category = serializers.CharField(max_length=20)
    title = serializers.CharField(max_length=120, required=False, allow_blank=True)
    target_amount = serializers.DecimalField(max_digits=14, decimal_places=2)
    monthly_contribution = serializers.DecimalField(max_digits=14, decimal_places=2)
    duration_months = serializers.IntegerField(min_value=3, max_value=24)
    pay_first_installment = serializers.BooleanField(default=True)


class ContributeGoalSerializer(serializers.Serializer):
    amount = serializers.DecimalField(max_digits=14, decimal_places=2, required=False)


class WithdrawGoalSerializer(serializers.Serializer):
    amount = serializers.DecimalField(max_digits=14, decimal_places=2, required=False)

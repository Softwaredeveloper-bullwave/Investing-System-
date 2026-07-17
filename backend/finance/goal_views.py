"""Goal plan API views."""

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from core.utils import camelize

from .goal_serializers import ContributeGoalSerializer, CreateGoalSerializer, WithdrawGoalSerializer
from .goal_service import (
    GoalError,
    contribute_to_goal,
    create_goal_plan,
    get_due_reminders,
    get_return_tiers,
    get_user_goals,
    serialize_goal,
    withdraw_from_goal,
)
from .models import GoalPlanTemplate, UserGoalPlan


class GoalTemplateListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        templates = GoalPlanTemplate.objects.filter(is_active=True)
        data = [
            {
                'id': t.id,
                'category': t.category,
                'name': t.name,
                'tagline': t.tagline,
                'icon': t.icon,
                'color': t.color,
                'minTarget': float(t.min_target),
                'suggestedMonthly': float(t.suggested_monthly),
                'minDurationMonths': t.min_duration_months,
                'maxDurationMonths': t.max_duration_months,
            }
            for t in templates
        ]
        return Response({'templates': data, 'returnTiers': get_return_tiers()})


class GoalPlanListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(camelize({'goals': get_user_goals(request.user)}))

    def post(self, request):
        ser = CreateGoalSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        data = ser.validated_data
        try:
            goal = create_goal_plan(
                request.user,
                category=data['category'],
                title=data.get('title') or '',
                target_amount=data['target_amount'],
                monthly_contribution=data['monthly_contribution'],
                duration_months=data['duration_months'],
                pay_first_installment=data.get('pay_first_installment', True),
            )
        except GoalError as exc:
            return Response({'detail': str(exc)}, status=400)
        return Response(camelize(serialize_goal(goal)), status=201)


class GoalPlanDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, goal_id):
        try:
            goal = UserGoalPlan.objects.select_related('template').get(
                pk=goal_id, user=request.user
            )
        except UserGoalPlan.DoesNotExist:
            return Response({'detail': 'Goal not found.'}, status=404)
        return Response(camelize(serialize_goal(goal)))


class GoalContributeView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, goal_id):
        try:
            goal = UserGoalPlan.objects.get(pk=goal_id, user=request.user)
        except UserGoalPlan.DoesNotExist:
            return Response({'detail': 'Goal not found.'}, status=404)

        ser = ContributeGoalSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        try:
            goal = contribute_to_goal(goal, ser.validated_data.get('amount'))
        except GoalError as exc:
            return Response({'detail': str(exc)}, status=400)
        return Response(camelize(serialize_goal(goal)))


class GoalWithdrawView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, goal_id):
        try:
            goal = UserGoalPlan.objects.get(pk=goal_id, user=request.user)
        except UserGoalPlan.DoesNotExist:
            return Response({'detail': 'Goal not found.'}, status=404)

        ser = WithdrawGoalSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        try:
            goal = withdraw_from_goal(goal, ser.validated_data.get('amount'))
        except GoalError as exc:
            return Response({'detail': str(exc)}, status=400)
        return Response(camelize(serialize_goal(goal)))


class GoalRemindersView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        due = get_due_reminders(request.user)
        active = [g for g in get_user_goals(request.user) if g['status'] == 'active']
        return Response(camelize({'due': due, 'activeCount': len(active)}))

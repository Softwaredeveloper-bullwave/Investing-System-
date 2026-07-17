"""Approve all pending KYC requests (dev/admin fallback when email links fail)."""

from django.core.management.base import BaseCommand

from accounts.models import User

from kyc.email_action_views import _get_email_reviewer
from kyc.manual_service import ManualKycError, approve_kyc_request
from kyc.models import KYCRequest


class Command(BaseCommand):
    help = 'Approve pending KYC requests from the terminal (fallback if email links fail).'

    def add_arguments(self, parser):
        parser.add_argument(
            '--phone',
            help='Approve only the pending request for this user phone (10 digits).',
        )
        parser.add_argument(
            '--all',
            action='store_true',
            help='Approve every pending KYC request.',
        )

    def handle(self, *args, **options):
        reviewer = _get_email_reviewer()
        self.stdout.write(f'Reviewer: {reviewer.phone} ({reviewer.name or "KYC reviewer"})')

        qs = KYCRequest.objects.filter(status=KYCRequest.Status.PENDING).select_related('user')
        phone = (options.get('phone') or '').strip()
        if phone:
            qs = qs.filter(user__phone=phone)
        elif not options.get('all'):
            count = qs.count()
            self.stdout.write(
                self.style.WARNING(
                    f'{count} pending request(s). Use --all to approve all, or --phone=9876543210 for one user.'
                )
            )
            return

        approved = 0
        for req in qs.order_by('created_at'):
            try:
                approve_kyc_request(req, reviewer)
                approved += 1
                self.stdout.write(self.style.SUCCESS(f'Approved {req.full_name} ({req.user.phone})'))
            except ManualKycError as exc:
                self.stderr.write(self.style.ERROR(f'Skip {req.user.phone}: {exc}'))

        self.stdout.write(self.style.SUCCESS(f'Done. Approved {approved} request(s). Users can refresh the app.'))

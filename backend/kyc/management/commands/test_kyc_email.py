from django.core.management.base import BaseCommand

from kyc.notifications import notify_admin_new_kyc_request, notify_user_kyc_approved


class Command(BaseCommand):
    help = 'Send test KYC emails (admin new request + user approval).'

    def handle(self, *args, **options):
        notify_admin_new_kyc_request(
            user_phone='9999999999',
            pan_number='ABCDE1234F',
            full_name='Test User',
            request_id='test-request-id',
            pan_image_paths=[],
        )
        notify_user_kyc_approved(
            user_phone='9999999999',
            full_name='Test User',
            user_email='',
        )
        self.stdout.write(self.style.SUCCESS('Triggered test KYC emails. Check inbox / console logs.'))

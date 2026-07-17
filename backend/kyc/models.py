import uuid

from django.conf import settings
from django.db import models


class KycProfile(models.Model):
    class VerificationStatus(models.TextChoices):
        PENDING = 'pending', 'Pending'
        VERIFIED = 'verified', 'Verified'
        FAILED = 'failed', 'Failed'

    class OverallStatus(models.TextChoices):
        PENDING = 'pending', 'Pending'
        VERIFIED = 'verified', 'Verified'
        REJECTED = 'rejected', 'Rejected'

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='kyc_profile'
    )
    mobile_verified = models.BooleanField(default=False)

    pan_number = models.CharField(max_length=10, blank=True, default='')
    pan_name = models.CharField(max_length=120, blank=True, default='')
    pan_status = models.CharField(
        max_length=20, choices=VerificationStatus.choices, default=VerificationStatus.PENDING
    )
    pan_reference_id = models.CharField(max_length=64, blank=True, default='')
    pan_failure_reason = models.CharField(max_length=280, blank=True, default='')
    pan_verified_at = models.DateTimeField(null=True, blank=True)

    account_holder_name = models.CharField(max_length=120, blank=True, default='')
    bank_name = models.CharField(max_length=120, blank=True, default='')
    bank_account_number = models.CharField(max_length=20, blank=True, default='')
    bank_ifsc = models.CharField(max_length=11, blank=True, default='')
    bank_branch = models.CharField(max_length=120, blank=True, default='')
    bank_status = models.CharField(
        max_length=20, choices=VerificationStatus.choices, default=VerificationStatus.PENDING
    )
    bank_reference_id = models.CharField(max_length=64, blank=True, default='')
    bank_failure_reason = models.CharField(max_length=280, blank=True, default='')
    bank_verified_at = models.DateTimeField(null=True, blank=True)
    name_at_bank = models.CharField(max_length=120, blank=True, default='')

    name_match_result = models.CharField(max_length=40, blank=True, default='')
    name_match_score = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    name_match_passed = models.BooleanField(default=False)
    name_match_checked_at = models.DateTimeField(null=True, blank=True)

    overall_status = models.CharField(
        max_length=20, choices=OverallStatus.choices, default=OverallStatus.PENDING
    )
    verified_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f'KYC {self.user.phone}'


class KYCRequest(models.Model):
    """Manual PAN KYC submission — reviewed by admin (no Cashfree)."""

    class Status(models.TextChoices):
        PENDING = 'PENDING', 'Pending'
        APPROVED = 'APPROVED', 'Approved'
        REJECTED = 'REJECTED', 'Rejected'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='kyc_requests'
    )
    pan_number = models.CharField(max_length=10)
    full_name = models.CharField(max_length=120)
    dob = models.DateField()
    pan_image = models.ImageField(upload_to='kyc/pan/%Y/%m/')
    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.PENDING
    )
    rejection_reason = models.CharField(max_length=500, blank=True, default='')
    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='kyc_reviews',
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [models.Index(fields=['status', 'created_at'])]

    @property
    def pan_image_url(self) -> str:
        if self.pan_image:
            return self.pan_image.url
        return ''

    def __str__(self):
        return f'KYCRequest {self.pan_number} ({self.status})'


class KYCRequestImage(models.Model):
    """Additional PAN / ID photos attached to a manual KYC request."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    request = models.ForeignKey(
        KYCRequest, on_delete=models.CASCADE, related_name='images'
    )
    image = models.ImageField(upload_to='kyc/pan/%Y/%m/')
    sort_order = models.PositiveSmallIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['sort_order', 'created_at']

    def __str__(self):
        return f'KYC image {self.request_id} #{self.sort_order}'


class FnoEligibilityRequest(models.Model):
    """F&O eligibility proof — admin review or instant portfolio check."""

    class ProofType(models.TextChoices):
        BANK_STATEMENT = 'bank_statement', '6-Month Bank Statement'
        FORM16 = 'form16', 'FORM 16'
        ITR = 'itr', 'ITR Form'
        PORTFOLIO_HOLDING = 'portfolio_holding', '₹50,000 Portfolio Holding'

    class Status(models.TextChoices):
        PENDING = 'PENDING', 'Pending'
        APPROVED = 'APPROVED', 'Approved'
        REJECTED = 'REJECTED', 'Rejected'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='fno_requests'
    )
    proof_type = models.CharField(max_length=32, choices=ProofType.choices)
    document = models.FileField(upload_to='fno/proofs/%Y/%m/', blank=True, null=True)
    portfolio_value = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    rejection_reason = models.CharField(max_length=500, blank=True, default='')
    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='fno_reviews',
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [models.Index(fields=['status', 'created_at'])]

    def __str__(self):
        return f'FNO {self.proof_type} ({self.status}) — {self.user_id}'


class VerificationAuditLog(models.Model):
    class Step(models.TextChoices):
        PAN = 'pan', 'PAN'
        BANK = 'bank', 'Bank'
        NAME_MATCH = 'name_match', 'Name Match'

    class Status(models.TextChoices):
        STARTED = 'started', 'Started'
        SUCCESS = 'success', 'Success'
        FAILED = 'failed', 'Failed'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='verification_logs'
    )
    step = models.CharField(max_length=20, choices=Step.choices)
    status = models.CharField(max_length=20, choices=Status.choices)
    message = models.CharField(max_length=500, blank=True, default='')
    request_meta = models.JSONField(default=dict, blank=True)
    response_meta = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [models.Index(fields=['user', 'step', 'created_at'])]

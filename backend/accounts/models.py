import uuid

from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.db import models


class UserManager(BaseUserManager):
    def create_user(self, phone, **extra_fields):
        if not phone:
            raise ValueError('Phone number is required')
        user = self.model(phone=phone, **extra_fields)
        user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, phone, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        user = self.create_user(phone, **extra_fields)
        if password:
            user.set_password(password)
            user.save(using=self._db)
        return user


class User(AbstractBaseUser, PermissionsMixin):
    class PanStatus(models.TextChoices):
        PENDING = 'pending', 'Pending'
        VERIFIED = 'verified', 'Verified'
        REJECTED = 'rejected', 'Rejected'

    class KycStatus(models.TextChoices):
        NOT_SUBMITTED = 'not_submitted', 'Not Submitted'
        PENDING = 'pending', 'Pending'
        VERIFIED = 'verified', 'Verified'
        REJECTED = 'rejected', 'Rejected'
        # Legacy values kept for existing rows
        IN_PROGRESS = 'in_progress', 'In Progress'
        COMPLETED = 'completed', 'Completed'

    class FnoStatus(models.TextChoices):
        NOT_SUBMITTED = 'not_submitted', 'Not Submitted'
        PENDING = 'pending', 'Pending'
        VERIFIED = 'verified', 'Verified'
        REJECTED = 'rejected', 'Rejected'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    phone = models.CharField(max_length=15, unique=True, db_index=True)
    name = models.CharField(max_length=120, blank=True)
    email = models.EmailField(blank=True)
    avatar = models.ImageField(upload_to='avatars/%Y/%m/', blank=True, null=True)
    avatar_url = models.URLField(blank=True, default='')
    date_of_birth = models.DateField(blank=True, null=True)
    city = models.CharField(max_length=80, blank=True)
    bio = models.CharField(max_length=280, blank=True)
    pan_status = models.CharField(
        max_length=20, choices=PanStatus.choices, default=PanStatus.PENDING
    )
    kyc_status = models.CharField(
        max_length=20, choices=KycStatus.choices, default=KycStatus.NOT_SUBMITTED
    )
    fno_status = models.CharField(
        max_length=20, choices=FnoStatus.choices, default=FnoStatus.NOT_SUBMITTED
    )
    referral_code = models.CharField(max_length=20, unique=True, blank=True)
    referred_by = models.ForeignKey(
        'self', null=True, blank=True, on_delete=models.SET_NULL, related_name='referrals'
    )
    has_completed_onboarding = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    date_joined = models.DateTimeField(auto_now_add=True)

    objects = UserManager()

    USERNAME_FIELD = 'phone'
    REQUIRED_FIELDS = []

    def save(self, *args, **kwargs):
        if not self.referral_code:
            import secrets
            suffix = self.phone[-4:] if self.phone else secrets.token_hex(2)
            self.referral_code = f'BW{suffix.upper()}{secrets.token_hex(2).upper()}'
        super().save(*args, **kwargs)

    def __str__(self):
        return self.phone


class OTPVerification(models.Model):
    phone = models.CharField(max_length=15, db_index=True)
    otp_code = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_used = models.BooleanField(default=False)

    class Meta:
        ordering = ['-created_at']


class BankAccount(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='bank_account')
    account_holder_name = models.CharField(max_length=120)
    bank_name = models.CharField(max_length=120)
    account_number = models.CharField(max_length=20)
    ifsc = models.CharField(max_length=11)
    pan_number = models.CharField(max_length=10)
    is_verified = models.BooleanField(default=False)
    verification_provider = models.CharField(max_length=20, blank=True, default='')
    verification_reference_id = models.CharField(max_length=64, blank=True, default='')
    verification_status = models.CharField(
        max_length=20,
        choices=[
            ('pending', 'Pending'),
            ('verified', 'Verified'),
            ('failed', 'Failed'),
        ],
        default='pending',
    )
    verification_message = models.CharField(max_length=280, blank=True, default='')
    name_at_bank = models.CharField(max_length=120, blank=True, default='')
    name_match_result = models.CharField(max_length=40, blank=True, default='')
    pan_registered_name = models.CharField(max_length=120, blank=True, default='')
    verified_at = models.DateTimeField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)


class KycDocument(models.Model):
    class DocumentType(models.TextChoices):
        PAN = 'pan', 'PAN'
        AADHAAR_FRONT = 'aadhaar_front', 'Aadhaar Front'
        AADHAAR_BACK = 'aadhaar_back', 'Aadhaar Back'
        SELFIE = 'selfie', 'Selfie'
        ADDRESS = 'address', 'Address Proof'

    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        APPROVED = 'approved', 'Approved'
        REJECTED = 'rejected', 'Rejected'

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='kyc_documents')
    document_type = models.CharField(max_length=20, choices=DocumentType.choices)
    file = models.FileField(upload_to='kyc/%Y/%m/')
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'document_type')

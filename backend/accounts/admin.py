from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin

from .models import BankAccount, KycDocument, OTPVerification, User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ('phone', 'name', 'kyc_status', 'pan_status', 'is_staff')
    search_fields = ('phone', 'name', 'email')
    ordering = ('phone',)
    fieldsets = (
        (None, {'fields': ('phone', 'password')}),
        ('Profile', {'fields': ('name', 'email', 'avatar_url', 'referral_code', 'referred_by')}),
        ('Verification', {'fields': ('pan_status', 'kyc_status', 'has_completed_onboarding')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
    )
    add_fieldsets = ((None, {'classes': ('wide',), 'fields': ('phone', 'password1', 'password2')}),)


admin.site.register(OTPVerification)
admin.site.register(BankAccount)
admin.site.register(KycDocument)

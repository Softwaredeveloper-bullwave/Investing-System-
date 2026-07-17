from django.contrib import admin

from .models import PayoutRecord


@admin.register(PayoutRecord)
class PayoutRecordAdmin(admin.ModelAdmin):
    list_display = ('transfer_id', 'user', 'amount', 'status', 'created_at', 'completed_at')
    list_filter = ('status',)
    search_fields = ('transfer_id', 'reference_id', 'user__phone')

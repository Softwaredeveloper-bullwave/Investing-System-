from django.contrib import admin

from .models import MarketIndex, MarketNews, Notification, ReferralReward, SupportFaq, SupportTicket

admin.site.register(Notification)
admin.site.register(SupportFaq)
admin.site.register(SupportTicket)
admin.site.register(ReferralReward)
admin.site.register(MarketIndex)
admin.site.register(MarketNews)

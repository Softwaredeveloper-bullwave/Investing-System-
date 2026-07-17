from django.contrib import admin

from .models import (
    InvestmentFaq,
    InvestmentPlan,
    PaymentOrder,
    Transaction,
    UserInvestment,
    Wallet,
    WalletTransaction,
)

admin.site.register(InvestmentPlan)
admin.site.register(UserInvestment)
admin.site.register(Wallet)
admin.site.register(WalletTransaction)
admin.site.register(Transaction)
admin.site.register(InvestmentFaq)
admin.site.register(PaymentOrder)

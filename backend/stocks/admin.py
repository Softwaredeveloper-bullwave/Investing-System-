from django.contrib import admin

from .models import (
    CopySubscription,
    CopyTraderProfile,
    CopyTraderTrade,
    DividendRecord,
    IpoEvent,
    IpoHolding,
    IpoTrade,
    NewsAlert,
    OptionContract,
    PaperCompetition,
    PaperCompetitionMember,
    BlockDeal,
    DarkPoolPrint,
    PaperTrade,
    PriceAlert,
    SipPlan,
    Stock,
    StockCandle,
    StockHolding,
    StockNews,
    TraderNote,
    WatchlistItem,
)

admin.site.register(Stock)
admin.site.register(StockCandle)
admin.site.register(WatchlistItem)
admin.site.register(StockHolding)
admin.site.register(PriceAlert)
admin.site.register(NewsAlert)
admin.site.register(SipPlan)
admin.site.register(PaperTrade)
admin.site.register(StockNews)
admin.site.register(OptionContract)
admin.site.register(DividendRecord)
admin.site.register(TraderNote)


@admin.register(IpoEvent)
class IpoEventAdmin(admin.ModelAdmin):
    list_display = ('company_name', 'status', 'open_date', 'close_date', 'listing_date', 'is_featured')
    list_filter = ('status', 'exchange', 'is_featured')
    search_fields = ('company_name', 'symbol', 'sector')


admin.site.register(IpoHolding)
admin.site.register(IpoTrade)


@admin.register(CopyTraderProfile)
class CopyTraderProfileAdmin(admin.ModelAdmin):
    list_display = (
        'display_name', 'handle', 'risk_level', 'is_verified',
        'return_3m', 'followers_count', 'is_active',
    )
    list_filter = ('risk_level', 'is_verified', 'is_active')
    search_fields = ('display_name', 'handle', 'strategy_title')


admin.site.register(CopyTraderTrade)
admin.site.register(CopySubscription)
admin.site.register(PaperCompetition)
admin.site.register(PaperCompetitionMember)
admin.site.register(BlockDeal)
admin.site.register(DarkPoolPrint)

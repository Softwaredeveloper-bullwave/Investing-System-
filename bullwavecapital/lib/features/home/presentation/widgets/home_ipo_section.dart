import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/stock_model.dart';
import '../../../stocks/presentation/provider/stock_features_provider.dart';
import 'home_theme_a.dart';

class HomeIpoSection extends StatelessWidget {
  const HomeIpoSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StockFeaturesProvider>(
      builder: (context, features, _) {
        final ipos = features.featuredIpos;
        final holdings = features.ipoHoldings;

        if (ipos.isEmpty && holdings.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeSectionHeader(
              title: 'IPO Calendar',
              actionLabel: 'View All',
              onAction: () => context.push(AppRoutes.ipoCalendar),
              reserveFabSpace: true,
            ),
            const SizedBox(height: 12),
            if (holdings.isNotEmpty) ...[
              ...holdings.take(2).map(
                    (h) => _HoldingPreview(holding: h),
                  ),
              const SizedBox(height: 12),
            ],
            if (ipos.isNotEmpty)
              SizedBox(
                height: 136,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: ipos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) =>
                      _IpoTeaserCard(event: ipos[index]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HoldingPreview extends StatelessWidget {
  final IpoHoldingModel holding;

  const _HoldingPreview({required this.holding});

  @override
  Widget build(BuildContext context) {
    final p = HomeThemeA.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: HomeThemeA.cardDecoration(context),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: HomeThemeA.iconCircleDecoration(context),
            child: Icon(
              PhosphorIcons.chartLineUp,
              size: 18,
              color: p.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holding.companyName,
                  style: context.typeCardTitle(14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${holding.lots} lot(s) • ${holding.canSell ? 'Listed' : 'Applied'}',
                  style: context.typeSecondary(13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                CurrencyFormatter.format(holding.currentValueInr),
                style: ThemeAType.price(size: 14, color: p.positive),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IpoTeaserCard extends StatelessWidget {
  final IpoEventModel event;

  const _IpoTeaserCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final isOpen = event.isOpen;
    final badgeColor = isOpen ? HomeThemeA.of(context).positive : const Color(0xFF2563EB);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(AppRoutes.ipoCalendar),
        borderRadius: BorderRadius.circular(HomeThemeA.cardRadius),
        child: Ink(
          width: 220,
          padding: const EdgeInsets.all(16),
          decoration: HomeThemeA.cardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: badgeColor.withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  isOpen ? 'OPEN' : 'UPCOMING',
                  style: context.typeLabel(11, badgeColor).copyWith(letterSpacing: 0.4),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                event.companyName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.typeCardTitle(15),
              ),
              const Spacer(),
              Text(
                event.priceBandLabel,
                style: context.typeSecondary(13),
              ),
              if (event.gmpPercent != null) ...[
                const SizedBox(height: 3),
                Text(
                  'GMP +${event.gmpPercent!.toStringAsFixed(1)}%',
                  style: context.typeLabel(13, HomeThemeA.of(context).positive),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

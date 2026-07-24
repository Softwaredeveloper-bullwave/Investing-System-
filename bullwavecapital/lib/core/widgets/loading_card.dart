import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme_extension.dart';
import '../constants/dimensions.dart';

class LoadingCard extends StatelessWidget {
  final double height;

  const LoadingCard({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Shimmer.fromColors(
      baseColor: colors.shimmerBase,
      highlightColor: colors.shimmerHighlight,
      child: Container(
        height: height,
        margin: const EdgeInsets.only(bottom: AppDimensions.paddingSm),
        decoration: BoxDecoration(
          color: colors.shimmerBase,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        ),
      ),
    );
  }
}

class LoadingList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const LoadingList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 80,
  });

  @override
  Widget build(BuildContext context) {
    // ListView (not Column) — most call sites drop this straight into a
    // Scaffold body via Padding with no scroll wrapper, so a plain Column
    // overflows ("RenderFlex overflowed") on any screen short enough that
    // itemCount * (itemHeight + margin) exceeds the available height (e.g.
    // IPO Calendar's 5 * 128 = 640 vs. a ~574 tall body). shrinkWrap keeps it
    // sized-to-content like the old Column (so it still nests fine inside
    // other scrollables), but being a real scroll view means it clips/scrolls
    // instead of throwing the overflow assertion when it doesn't fit.
    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (context, _) => LoadingCard(height: itemHeight),
    );
  }
}

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
    return Column(
      children: List.generate(itemCount, (_) => LoadingCard(height: itemHeight)),
    );
  }
}

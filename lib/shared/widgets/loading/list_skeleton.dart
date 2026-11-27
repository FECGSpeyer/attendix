import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import 'skeleton_list_tile.dart';

/// A complete skeleton list with multiple items
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({
    super.key,
    this.itemCount = 8,
    this.showAvatar = true,
    this.showSubtitle = true,
    this.showTrailing = false,
    this.showDividers = false,
    this.padding,
  });

  final int itemCount;
  final bool showAvatar;
  final bool showSubtitle;
  final bool showTrailing;
  final bool showDividers;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding ?? const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      separatorBuilder: (context, index) {
        if (showDividers) {
          return const Divider(height: 1, indent: 72);
        }
        return const SizedBox(height: 4);
      },
      itemBuilder: (context, index) {
        return SkeletonListTile(
          showAvatar: showAvatar,
          showSubtitle: showSubtitle,
          showTrailing: showTrailing,
        );
      },
    );
  }
}

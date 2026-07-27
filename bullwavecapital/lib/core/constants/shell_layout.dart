/// Layout constants for the main shell (bottom nav + AI FAB).
class ShellLayout {
  ShellLayout._();

  /// Bottom nav bar total footprint: SafeArea bottom minimum (8) + outer
  /// padding (6) + the nav Stack's height (82, which includes the floating
  /// center action button poking above the 66px bar). Keep in sync with
  /// AppBottomNavigation's layout in bottom_navigation.dart.
  static const double bottomNavHeight = 96;

  /// Gap between bottom nav top edge and FAB bottom edge.
  static const double fabAboveNavGap = 16;

  /// FAB tap target diameter.
  static const double fabSize = 56;

  /// Distance from screen bottom to FAB bottom edge (above bottom nav).
  static const double fabBottomOffset = bottomNavHeight + fabAboveNavGap;

  /// Distance from screen right to FAB right edge.
  static const double fabRightOffset = 16;

  /// Reserve trailing space so section actions clear the floating AI button.
  static const double fabActionClearance = fabRightOffset + fabSize + 16;

  /// Bottom inset so scroll content clears nav bar + AI assistant FAB.
  static const double contentBottomInset = fabBottomOffset + fabSize + 24;
}

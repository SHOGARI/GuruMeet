import 'package:flutter/material.dart';

abstract final class AppBreakpoints {
  static const double compact = 480;
  static const double stackedActions = 520;
}

abstract final class AppSpacing {
  static const double micro = 4;
  static const double small = 8;
  static const double regular = 12;
  static const double medium = 16;
  static const double large = 20;
  static const double xLarge = 24;
  static const double xxLarge = 32;
  static const double section = 40;
  static const double hero = 52;
}

abstract final class AppRadius {
  static const double small = 16;
  static const double control = 20;
  static const double card = 32;
}

abstract final class AppSizes {
  static const double contentMaxWidth = 680;
  static const double homeMaxWidth = 760;
  static const double actionMaxWidth = 480;
  static const double restaurantCardMaxWidth = 560;
  static const double toolbarHeight = 64;
  static const double primaryButtonHeight = 64;
  static const double secondaryButtonHeight = 56;
  static const double bottomBarClearance = 180;
  static const double touchTarget = 48;
  static const double successIndicator = 52;
  static const double iconMedium = 20;
  static const double iconLarge = 28;
  static const double summaryLabelWidth = 72;
  static const double codeLabelLetterSpacing = 1.6;
  static const double groupCodeLetterSpacing = 2.4;
  static const double progressIndicatorHeight = 6;
}

abstract final class AppMotion {
  static const Duration quick = Duration(milliseconds: 110);
  static const Duration pageEntrance = Duration(milliseconds: 420);
  static const double pressedScale = 0.985;
}

abstract final class AppShadows {
  static List<BoxShadow> restaurantCard(Color color, {required bool muted}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: muted ? 0.025 : 0.055),
        blurRadius: muted ? 16 : 32,
        offset: const Offset(0, 16),
      ),
    ];
  }
}

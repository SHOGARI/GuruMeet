import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
    this.appBar,
    this.bottomBar,
    this.maxContentWidth = AppSizes.contentMaxWidth,
  });

  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? bottomBar;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < AppBreakpoints.compact
        ? AppSpacing.large
        : AppSpacing.xLarge;

    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.large,
            horizontalPadding,
            bottomBar == null
                ? AppSpacing.section
                : AppSizes.bottomBarClearance,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: child,
            ),
          ),
        ),
      ),
      bottomNavigationBar: bottomBar == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  AppSpacing.regular,
                  horizontalPadding,
                  AppSpacing.large,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSizes.actionMaxWidth,
                    ),
                    child: SizedBox(width: double.infinity, child: bottomBar),
                  ),
                ),
              ),
            ),
    );
  }
}

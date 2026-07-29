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
    final horizontalPadding = switch (screenWidth) {
      < AppBreakpoints.compact => AppSpacing.medium,
      < 900 => AppSpacing.xLarge,
      _ => AppSpacing.xxLarge,
    };
    final topPadding = screenWidth < AppBreakpoints.compact
        ? AppSpacing.regular
        : AppSpacing.large;
    final body = SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        bottomBar == null ? AppSpacing.xLarge : AppSizes.bottomBarClearance,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: child,
        ),
      ),
    );

    return Scaffold(
      appBar: appBar,
      body: SafeArea(child: screenWidth >= 900 ? Scrollbar(child: body) : body),
      bottomNavigationBar: bottomBar == null
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: SafeArea(
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
            ),
    );
  }
}

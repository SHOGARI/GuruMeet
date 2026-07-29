import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../widgets/app_shell.dart';
import 'home_page.dart';
import 'join_group_page.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, this.requestedRoute});

  static const routeName = '/not-found';

  final String? requestedRoute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final visibleRoute = requestedRoute?.trim();

    return AppShell(
      appBar: AppBar(title: const Text('ページが見つかりません')),
      maxContentWidth: AppSizes.homeMaxWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSizes.successIndicator,
            height: AppSizes.successIndicator,
            decoration: BoxDecoration(
              color: colors.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search_off_rounded, color: colors.error),
          ),
          const SizedBox(height: AppSpacing.xLarge),
          Text(
            '404',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.error,
              letterSpacing: AppSizes.codeLabelLetterSpacing,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          Text('ページが見つかりません。', style: theme.textTheme.headlineLarge),
          const SizedBox(height: AppSpacing.regular),
          Text(
            '招待URLが途中で切れているか、すでに使えないリンクの可能性があります。',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          if (visibleRoute != null && visibleRoute.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.large),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.medium),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: SelectableText(
                visibleRoute,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.section),
          LayoutBuilder(
            builder: (context, constraints) {
              final buttons = [
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      HomePage.routeName,
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('ホームへ戻る'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      JoinGroupPage.routeName,
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.tag_rounded),
                  label: const Text('コードで参加する'),
                ),
              ];

              if (constraints.maxWidth < AppBreakpoints.stackedActions) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < buttons.length; index++) ...[
                      if (index > 0) const SizedBox(height: AppSpacing.small),
                      buttons[index],
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  for (var index = 0; index < buttons.length; index++) ...[
                    if (index > 0) const SizedBox(width: AppSpacing.small),
                    Expanded(child: buttons[index]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

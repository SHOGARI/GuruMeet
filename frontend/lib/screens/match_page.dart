import 'package:flutter/material.dart';

import '../models/group_creation_draft.dart';
import '../models/restaurant_preview.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_shell.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/restaurant_image.dart';
import 'home_page.dart';
import 'restaurant_detail_page.dart';

class MatchPage extends StatelessWidget {
  const MatchPage({super.key, required this.draft, required this.restaurant});

  static const routeName = '/match';

  final GroupCreationDraft draft;
  final RestaurantPreview restaurant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AppShell(
      appBar: AppBar(title: const Text('結果')),
      maxContentWidth: AppSizes.homeMaxWidth,
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryActionButton(
            label: '店舗詳細を見る',
            onPressed: () {
              Navigator.of(context).pushNamed(
                RestaurantDetailPage.routeName,
                arguments: (draft: draft, restaurant: restaurant),
              );
            },
          ),
          const SizedBox(height: AppSpacing.small),
          OutlinedButton(
            onPressed: () {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(HomePage.routeName, (route) => false);
            },
            child: const Text('ホームへ戻る'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.regular,
              vertical: AppSpacing.small,
            ),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Text(
              "IT'S A MATCH",
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onPrimaryContainer,
                letterSpacing: AppSizes.codeLabelLetterSpacing,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xLarge),
          Text('今日のお店は\nここに決まり。', style: theme.textTheme.headlineLarge),
          const SizedBox(height: AppSpacing.regular),
          Text(
            '${draft.peopleCount}人の「食べたい」が重なりました。',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xLarge),
          Material(
            color: colors.surfaceContainerLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: RestaurantImage(
                    imageUrl: restaurant.imageUrl,
                    semanticLabel: '${restaurant.name}の料理写真',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.large),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurant.name,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.small),
                      Text(
                        '${restaurant.cuisine}  ·  ${restaurant.area}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.micro),
                      Text(
                        restaurant.budget,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.regular),
                      Text(
                        restaurant.description,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

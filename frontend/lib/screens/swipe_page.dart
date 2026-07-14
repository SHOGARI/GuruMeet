import 'package:flutter/material.dart';

import '../models/group_creation_draft.dart';
import '../models/restaurant_preview.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_shell.dart';
import '../widgets/restaurant_image.dart';
import 'match_page.dart';

class SwipePage extends StatefulWidget {
  const SwipePage({super.key, required this.draft});

  static const routeName = '/swipe';

  final GroupCreationDraft draft;

  @override
  State<SwipePage> createState() => _SwipePageState();
}

class _SwipePageState extends State<SwipePage> {
  int _currentIndex = 0;
  int _currentParticipantIndex = 0;
  final Map<String, int> _likeCounts = {};
  bool _isResolvingChoice = false;

  RestaurantPreview get _currentRestaurant => mockRestaurants[_currentIndex];

  String get _participantLabel => _currentParticipantIndex == 0
      ? 'あなた（ホスト）'
      : '参加者 ${_currentParticipantIndex + 1}';

  void _chooseRestaurant({required bool liked}) {
    if (_isResolvingChoice || _currentIndex >= mockRestaurants.length) {
      return;
    }
    _isResolvingChoice = true;
    final currentRestaurant = _currentRestaurant;
    if (liked) {
      _likeCounts.update(
        currentRestaurant.id,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    if (_currentIndex == mockRestaurants.length - 1) {
      if (_currentParticipantIndex == widget.draft.peopleCount - 1) {
        final matchedRestaurant = _resolveMatch(fallback: currentRestaurant);
        Navigator.of(context).pushReplacementNamed(
          MatchPage.routeName,
          arguments: (draft: widget.draft, restaurant: matchedRestaurant),
        );
        return;
      }

      setState(() {
        _currentParticipantIndex++;
        _currentIndex = 0;
        _isResolvingChoice = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_participantLabel にスマホを渡してください')),
      );
      return;
    }

    setState(() {
      _currentIndex++;
      _isResolvingChoice = false;
    });
  }

  RestaurantPreview _resolveMatch({required RestaurantPreview fallback}) {
    RestaurantPreview matchedRestaurant = fallback;
    var highestLikeCount = -1;

    for (final restaurant in mockRestaurants) {
      final likeCount = _likeCounts[restaurant.id] ?? 0;
      if (likeCount > highestLikeCount) {
        highestLikeCount = likeCount;
        matchedRestaurant = restaurant;
      }
    }
    return matchedRestaurant;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AppShell(
      appBar: AppBar(title: const Text('お店を選ぶ')),
      maxContentWidth: AppSizes.homeMaxWidth,
      bottomBar: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isResolvingChoice
                  ? null
                  : () => _chooseRestaurant(liked: false),
              child: const Text('パス'),
            ),
          ),
          const SizedBox(width: AppSpacing.regular),
          Expanded(
            child: FilledButton(
              onPressed: _isResolvingChoice
                  ? null
                  : () => _chooseRestaurant(liked: true),
              child: const Text('食べたい'),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('食べたい？', style: theme.textTheme.headlineMedium),
              ),
              Text(
                '${_currentIndex + 1} / ${mockRestaurants.length}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.small),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.small),
            child: LinearProgressIndicator(
              minHeight: AppSizes.progressIndicatorHeight,
              value: (_currentIndex + 1) / mockRestaurants.length,
              backgroundColor: colors.surfaceContainerHigh,
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          Text(
            '$_participantLabel の番です  ·  ${_currentParticipantIndex + 1} / ${widget.draft.peopleCount}人',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xLarge),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.restaurantCardMaxWidth,
              ),
              child: _SwipeCard(
                key: ValueKey(_currentRestaurant.id),
                restaurant: _currentRestaurant,
                onDismissed: (direction) {
                  _chooseRestaurant(
                    liked: direction == DismissDirection.startToEnd,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeCard extends StatelessWidget {
  const _SwipeCard({
    super.key,
    required this.restaurant,
    required this.onDismissed,
  });

  final RestaurantPreview restaurant;
  final ValueChanged<DismissDirection> onDismissed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Dismissible(
      key: ValueKey('dismiss-${restaurant.id}'),
      direction: DismissDirection.horizontal,
      onDismissed: onDismissed,
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        label: '食べたい',
        color: colors.primaryContainer,
      ),
      secondaryBackground: _SwipeBackground(
        alignment: Alignment.centerRight,
        label: 'パス',
        color: colors.surfaceContainerHigh,
      ),
      child: Material(
        color: colors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        elevation: 0,
        shadowColor: colors.shadow,
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
              padding: const EdgeInsets.all(AppSpacing.xLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(restaurant.name, style: theme.textTheme.headlineSmall),
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
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.label,
    required this.color,
  });

  final Alignment alignment;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xLarge),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

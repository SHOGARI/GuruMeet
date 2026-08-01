import 'package:flutter/material.dart';

import '../models/restaurant_preview.dart';
import '../theme/app_tokens.dart';
import 'restaurant_image.dart';

class HeroCardStack extends StatelessWidget {
  const HeroCardStack({super.key});

  static const double _stackHeight = 456;
  static const double _compactStackHeight = 268;
  static const double _frontCardHeight = 408;
  static const double _compactFrontCardHeight = 252;
  static const double _cardWidthFactor = 0.86;
  static const double _minimumCardWidth = 268;
  static const double _maximumCardWidth = 486;
  static const double _middleCardScale = 0.94;
  static const double _backCardScale = 0.87;
  static const double _sideOffsetFactor = 0.1;
  static const double _minimumSideOffset = 28;
  static const double _maximumSideOffset = 58;
  static const double _gentleRotation = 0.072;

  static const _featuredRestaurant = RestaurantPreview(
    id: 'gyuraku-home',
    name: '炭火焼肉 牛楽',
    area: '新宿',
    budget: '¥2,000〜3,000',
    cuisine: '焼肉',
    description: '香ばしい炭火焼肉をみんなで囲める、今夜の本命候補。',
    imageUrls: [
      'https://images.unsplash.com/photo-1529692236671-f1f6cf9683ba?auto=format&fit=crop&w=1200&q=90',
      'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=1200&q=90',
    ],
  );

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompactHeight = screenHeight < 860;
    final isCompactWidth = screenWidth < AppBreakpoints.compact;
    final stackHeight = isCompactHeight ? _compactStackHeight : _stackHeight;
    final frontCardHeight = isCompactHeight
        ? _compactFrontCardHeight
        : _frontCardHeight;

    return SizedBox(
      height: stackHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = (constraints.maxWidth * _cardWidthFactor).clamp(
            _minimumCardWidth,
            _maximumCardWidth,
          );
          final sideOffset = (constraints.maxWidth * _sideOffsetFactor).clamp(
            _minimumSideOffset,
            _maximumSideOffset,
          );
          final backOffset = isCompactWidth
              ? const Offset(-34, AppSpacing.large)
              : Offset(-sideOffset, AppSpacing.large);
          final middleOffset = isCompactWidth
              ? const Offset(34, AppSpacing.regular)
              : Offset(sideOffset, AppSpacing.regular);
          final rotation = isCompactWidth
              ? _gentleRotation * 0.56
              : _gentleRotation;

          return Stack(
            clipBehavior: Clip.hardEdge,
            alignment: Alignment.center,
            children: [
              _RestaurantCard(
                preview: mockRestaurants[3],
                width: cardWidth * _backCardScale,
                height: frontCardHeight * 0.9,
                offset: backOffset,
                rotation: -rotation,
                muted: true,
              ),
              _RestaurantCard(
                preview: mockRestaurants[1],
                width: cardWidth * _middleCardScale,
                height: frontCardHeight * 0.96,
                offset: middleOffset,
                rotation: rotation,
                muted: true,
              ),
              _RestaurantCard(
                preview: _featuredRestaurant,
                width: cardWidth,
                height: frontCardHeight,
                offset: Offset.zero,
                rotation: 0,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({
    required this.preview,
    required this.width,
    required this.height,
    required this.offset,
    required this.rotation,
    this.muted = false,
  });

  final RestaurantPreview preview;
  final double width;
  final double height;
  final Offset offset;
  final double rotation;
  final bool muted;

  static const double _radius = AppRadius.card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: rotation,
        child: Opacity(
          opacity: muted ? 0.74 : 1,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(
                color: colors.outlineVariant.withValues(
                  alpha: muted ? 0.16 : 0.22,
                ),
              ),
              boxShadow: AppShadows.restaurantCard(colors.shadow, muted: muted),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: RestaurantImage(
                    imageUrl: preview.imageUrl,
                    semanticLabel: '${preview.name}の料理写真',
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.medium,
                      AppSpacing.small,
                      AppSpacing.medium,
                      AppSpacing.small,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          preview.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            letterSpacing: 0,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.micro),
                        Text(
                          '${preview.area}  ·  ${preview.budget}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

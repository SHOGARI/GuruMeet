import 'package:flutter/material.dart';

import '../models/restaurant_preview.dart';
import '../theme/app_tokens.dart';
import 'restaurant_image.dart';

class HeroCardStack extends StatelessWidget {
  const HeroCardStack({super.key});

  static const double _stackHeight = 276;
  static const double _frontCardHeight = 258;
  static const double _cardWidthFactor = 0.74;
  static const double _minimumCardWidth = 270;
  static const double _maximumCardWidth = 430;
  static const double _backCardScale = 0.91;
  static const double _backCardHeightScale = 0.93;
  static const double _sideOffsetFactor = 0.09;
  static const double _minimumSideOffset = 24;
  static const double _maximumSideOffset = 54;
  static const double _backCardRotation = 0.04;
  static const double _frontCardRotation = -0.008;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _stackHeight,
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

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              _RestaurantCard(
                preview: mockRestaurants[1],
                width: cardWidth * _backCardScale,
                height: _frontCardHeight * _backCardHeightScale,
                offset: Offset(sideOffset, AppSpacing.small),
                rotation: _backCardRotation,
                muted: true,
              ),
              _RestaurantCard(
                preview: mockRestaurants[2],
                width: cardWidth,
                height: _frontCardHeight,
                offset: Offset.zero,
                rotation: _frontCardRotation,
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
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: colors.outlineVariant.withValues(
                  alpha: muted ? 0.42 : 0.72,
                ),
              ),
              boxShadow: AppShadows.restaurantCard(colors.shadow, muted: muted),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: RestaurantImage(
                    imageUrl: preview.imageUrl,
                    semanticLabel: '${preview.name}の料理写真',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.medium,
                    AppSpacing.regular,
                    AppSpacing.medium,
                    AppSpacing.medium,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preview.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.micro),
                      Text(
                        '${preview.area}  ·  ${preview.budget}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
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

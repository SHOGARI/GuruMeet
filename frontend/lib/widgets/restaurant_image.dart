import 'dart:math' as math;

import 'package:flutter/material.dart';

int restaurantImageCacheWidth(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);
  return math.min(
    1600,
    math.max(
      720,
      (mediaQuery.size.width * mediaQuery.devicePixelRatio).round(),
    ),
  );
}

String? normalizedRestaurantImageUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final withScheme = trimmed.startsWith('//') ? 'https:$trimmed' : trimmed;
  final uri = Uri.tryParse(withScheme);
  if (uri == null || !uri.hasScheme) {
    return null;
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return null;
  }
  if (uri.scheme == 'http') {
    return uri.replace(scheme: 'https').toString();
  }
  return uri.toString();
}

ImageProvider<Object>? restaurantImageProvider(
  String imageUrl, {
  required int cacheWidth,
}) {
  final normalizedUrl = normalizedRestaurantImageUrl(imageUrl);
  if (normalizedUrl == null) {
    return null;
  }
  return ResizeImage.resizeIfNeeded(
    cacheWidth,
    null,
    NetworkImage(normalizedUrl),
  );
}

class RestaurantImage extends StatelessWidget {
  const RestaurantImage({
    super.key,
    required this.imageUrl,
    required this.semanticLabel,
    this.fit = BoxFit.cover,
  });

  final String imageUrl;
  final String semanticLabel;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final effectiveImageUrl = normalizedRestaurantImageUrl(imageUrl);
    if (effectiveImageUrl == null) {
      return _ImagePlaceholder(colors: colors);
    }

    return Image.network(
      effectiveImageUrl,
      semanticLabel: semanticLabel,
      width: double.infinity,
      height: double.infinity,
      fit: fit,
      cacheWidth: restaurantImageCacheWidth(context),
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (context, error, stackTrace) {
        return _ImagePlaceholder(colors: colors);
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return _ImageSkeleton(color: colors.surfaceContainerHighest);
      },
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          color: colors.onSurfaceVariant.withValues(alpha: 0.54),
          size: 44,
        ),
      ),
    );
  }
}

class _ImageSkeleton extends StatefulWidget {
  const _ImageSkeleton({required this.color});

  final Color color;

  @override
  State<_ImageSkeleton> createState() => _ImageSkeletonState();
}

class _ImageSkeletonState extends State<_ImageSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final alpha = 0.56 + (_controller.value * 0.2);
        return ColoredBox(color: widget.color.withValues(alpha: alpha));
      },
    );
  }
}

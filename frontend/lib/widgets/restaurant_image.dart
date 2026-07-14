import 'package:flutter/material.dart';

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
    final placeholderColor = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest;

    return Image.network(
      imageUrl,
      semanticLabel: semanticLabel,
      width: double.infinity,
      height: double.infinity,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return ColoredBox(color: placeholderColor);
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return ColoredBox(color: placeholderColor);
      },
    );
  }
}

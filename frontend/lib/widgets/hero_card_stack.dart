import 'package:flutter/material.dart';

class HeroCardStack extends StatelessWidget {
  const HeroCardStack({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 252,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth.clamp(280.0, 420.0) * 0.78;
          final cardHeight = constraints.maxHeight * 0.84;

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              _BackCard(
                width: cardWidth * 0.92,
                height: cardHeight,
                offset: const Offset(-18, 14),
                rotation: -0.05,
                title: '炭火ビストロ hibana',
                area: '渋谷',
                budget: '3,000〜5,000円',
              ),
              _BackCard(
                width: cardWidth * 0.92,
                height: cardHeight,
                offset: const Offset(18, 0),
                rotation: 0.05,
                title: '小皿ダイニング noto',
                area: '恵比寿',
                budget: '2,000〜3,000円',
              ),
              _FrontCard(width: cardWidth, height: cardHeight),
            ],
          );
        },
      ),
    );
  }
}

class _FrontCard extends StatelessWidget {
  const _FrontCard({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Transform.rotate(
      angle: -0.015,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x16000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2EC),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Stack(
                  children: [
                    Positioned(
                      top: 14,
                      right: 14,
                      child: _CardChip(label: '人気候補'),
                    ),
                    Center(child: _DishArtwork()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '食堂 こはる',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _MetaText(
              label: 'エリア',
              value: '中目黒',
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 6),
            _MetaText(
              label: '予算',
              value: '2,000〜3,000円',
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _BackCard extends StatelessWidget {
  const _BackCard({
    required this.width,
    required this.height,
    required this.offset,
    required this.rotation,
    required this.title,
    required this.area,
    required this.budget,
  });

  final double width;
  final double height;
  final Offset offset;
  final double rotation;
  final String title;
  final String area;
  final String budget;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3EE),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Center(child: _DishArtwork(compact: true)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 6),
                _MetaText(
                  label: 'エリア',
                  value: area,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.85),
                ),
                const SizedBox(height: 4),
                _MetaText(
                  label: '予算',
                  value: budget,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.85),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DishArtwork extends StatelessWidget {
  const _DishArtwork({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final plateSize = compact ? 86.0 : 118.0;
    final bowlSize = compact ? 48.0 : 64.0;

    return SizedBox(
      width: plateSize,
      height: plateSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: plateSize,
            height: plateSize,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF5C7B5)),
            ),
          ),
          Container(
            width: plateSize * 0.68,
            height: plateSize * 0.68,
            decoration: const BoxDecoration(
              color: Color(0xFFFFE2D5),
              shape: BoxShape.circle,
            ),
          ),
          Positioned(
            top: compact ? 20 : 28,
            child: Container(
              width: bowlSize,
              height: bowlSize,
              decoration: BoxDecoration(
                color: const Color(0xFFF07D57),
                borderRadius: BorderRadius.circular(compact ? 16 : 20),
              ),
            ),
          ),
          Positioned(
            bottom: compact ? 20 : 24,
            left: compact ? 22 : 28,
            child: Container(
              width: compact ? 22 : 28,
              height: compact ? 22 : 28,
              decoration: const BoxDecoration(
                color: Color(0xFFFFB88E),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: compact ? 18 : 26,
            right: compact ? 20 : 28,
            child: Container(
              width: compact ? 28 : 36,
              height: compact ? 10 : 12,
              decoration: BoxDecoration(
                color: const Color(0xFFF3C865),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardChip extends StatelessWidget {
  const _CardChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF07D57),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

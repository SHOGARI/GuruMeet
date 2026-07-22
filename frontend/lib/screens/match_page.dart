import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/group_creation_draft.dart';
import '../models/restaurant_preview.dart';
import '../models/result_summary.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_shell.dart';
import '../widgets/restaurant_image.dart';
import 'home_page.dart';
import 'restaurant_detail_page.dart';
import 'swipe_page.dart';

class MatchPage extends StatefulWidget {
  const MatchPage({super.key, required this.draft, required this.result});

  static const routeName = '/match';

  final GroupCreationDraft draft;
  final RestaurantMatchResult result;

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage>
    with SingleTickerProviderStateMixin {
  late final ResultSummary _summary;
  late final AnimationController _controller;
  bool _isNavigating = false;
  bool _isOpeningMaps = false;
  bool _hasConfirmed = false;

  RestaurantPreview get restaurant => _summary.winner.restaurant;

  @override
  void initState() {
    super.initState();
    _summary = ResultSummary.fromMatchResult(widget.result);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openMaps() async {
    if (_isOpeningMaps) {
      return;
    }
    setState(() => _isOpeningMaps = true);
    final query = Uri.encodeComponent(
      '${restaurant.name} ${restaurant.address}',
    );
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Googleマップを開けませんでした')));
    }
    if (mounted) {
      setState(() => _isOpeningMaps = false);
    }
  }

  void _confirmRestaurant() {
    if (_hasConfirmed) {
      return;
    }
    setState(() => _hasConfirmed = true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${restaurant.name} に決定しました')));
  }

  void _restartVoting({required bool runoff}) {
    if (_isNavigating) {
      return;
    }
    setState(() => _isNavigating = true);
    if (runoff) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_summary.topResults.length}店舗で決選投票を開始します（デモ）'),
        ),
      );
    }
    Navigator.of(
      context,
    ).pushReplacementNamed(SwipePage.routeName, arguments: widget.draft);
  }

  void _openDetail() {
    Navigator.of(context).pushNamed(
      RestaurantDetailPage.routeName,
      arguments: (draft: widget.draft, restaurant: restaurant),
    );
  }

  void _goHome() {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(HomePage.routeName, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppShell(
      appBar: AppBar(title: const Text('結果')),
      maxContentWidth: AppSizes.homeMaxWidth,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _ConfettiPainter(progress: _controller.value),
                  );
                },
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ResultHeader(summary: _summary),
              const SizedBox(height: AppSpacing.xLarge),
              ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(
                  CurvedAnimation(
                    parent: _controller,
                    curve: const Interval(0, 0.55, curve: Curves.easeOutBack),
                  ),
                ),
                child: _WinnerCard(summary: _summary),
              ),
              const SizedBox(height: AppSpacing.section),
              _ResultActions(
                hasTie: _summary.hasTie,
                onOpenMaps: _isOpeningMaps || _isNavigating ? null : _openMaps,
                onConfirm: _hasConfirmed || _isNavigating
                    ? null
                    : _confirmRestaurant,
                onRestart: _isNavigating
                    ? null
                    : () => _restartVoting(runoff: false),
                onRunoff: _summary.hasTie
                    ? (_isNavigating
                          ? null
                          : () => _restartVoting(runoff: true))
                    : null,
                onOpenDetail: _openDetail,
                onGoHome: _goHome,
              ),
              const SizedBox(height: AppSpacing.section),
              Text('ランキング', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.medium),
              ..._summary.podiumResults.map(
                (result) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.regular),
                  child: _RankedResultTile(
                    result: result,
                    selected: result.restaurant.id == restaurant.id,
                  ),
                ),
              ),
              if (_summary.rankedResults.length > 3) ...[
                const SizedBox(height: AppSpacing.medium),
                Text('みんなの集計', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.medium),
                ..._summary.rankedResults
                    .skip(3)
                    .map(
                      (result) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.regular,
                        ),
                        child: _RankedResultTile(
                          result: result,
                          selected: false,
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.summary});

  final ResultSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
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
            summary.hasTie ? 'FINAL ROUND' : "IT'S A MATCH",
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.onPrimaryContainer,
              letterSpacing: AppSizes.codeLabelLetterSpacing,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xLarge),
        Text(
          summary.hasTie ? '同率1位。\n決選投票へ。' : '今日のお店は\nここに決まり。',
          style: theme.textTheme.headlineLarge,
        ),
        const SizedBox(height: AppSpacing.regular),
        Text(
          summary.hasTie
              ? '${summary.topResults.length}店舗が同じ支持数で並びました。'
              : '${summary.winner.likeCount} / ${summary.peopleCount}人が「食べたい」を選びました。',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _WinnerCard extends StatelessWidget {
  const _WinnerCard({required this.summary});

  final ResultSummary summary;

  RestaurantResult get winner => summary.winner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final restaurant = winner.restaurant;

    return Material(
      color: colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: colors.primary.withValues(alpha: 0.28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: RestaurantImage(
                  imageUrl: restaurant.imageUrl,
                  semanticLabel: '${restaurant.name}の料理写真',
                ),
              ),
              Positioned(
                left: AppSpacing.large,
                top: AppSpacing.large,
                child: _RankBadge(
                  label: summary.hasTie ? '同率1位' : '1位',
                  icon: Icons.workspace_premium_rounded,
                ),
              ),
              if (winner.isUnanimous)
                const Positioned(
                  right: AppSpacing.large,
                  top: AppSpacing.large,
                  child: _UnanimousBadge(),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.large),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('この店に決定', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.small),
                Text(
                  restaurant.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.small),
                Wrap(
                  spacing: AppSpacing.small,
                  runSpacing: AppSpacing.small,
                  children: [
                    _MetricPill(label: restaurant.cuisine),
                    _MetricPill(label: restaurant.budget),
                    _MetricPill(label: restaurant.distance),
                  ],
                ),
                const SizedBox(height: AppSpacing.large),
                Row(
                  children: [
                    Expanded(
                      child: _VoteMetric(
                        label: 'いいね',
                        value: '${winner.likeCount}',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Expanded(
                      child: _VoteMetric(
                        label: '拒否',
                        value: '${winner.rejectCount}',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Expanded(
                      child: _VoteMetric(
                        label: 'いいね率',
                        value: '${(winner.likeRate * 100).round()}%',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultActions extends StatelessWidget {
  const _ResultActions({
    required this.hasTie,
    required this.onOpenMaps,
    required this.onConfirm,
    required this.onRestart,
    required this.onRunoff,
    required this.onOpenDetail,
    required this.onGoHome,
  });

  final bool hasTie;
  final VoidCallback? onOpenMaps;
  final VoidCallback? onConfirm;
  final VoidCallback? onRestart;
  final VoidCallback? onRunoff;
  final VoidCallback onOpenDetail;
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final buttons = <Widget>[
          FilledButton.icon(
            onPressed: onOpenMaps,
            icon: const Icon(Icons.map_rounded),
            label: const Text('Googleマップで開く'),
          ),
          FilledButton.tonalIcon(
            onPressed: onConfirm,
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('この店に決定'),
          ),
          if (hasTie)
            FilledButton.tonalIcon(
              onPressed: onRunoff,
              icon: const Icon(Icons.how_to_vote_rounded),
              label: const Text('決選投票をする'),
            ),
          OutlinedButton.icon(
            onPressed: onRestart,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('もう一度選ぶ'),
          ),
          OutlinedButton(onPressed: onOpenDetail, child: const Text('店舗詳細を見る')),
          TextButton(onPressed: onGoHome, child: const Text('ホームへ戻る')),
        ];

        if (constraints.maxWidth < 620) {
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

        return Wrap(
          spacing: AppSpacing.small,
          runSpacing: AppSpacing.small,
          children: buttons.map((button) {
            return SizedBox(
              width: (constraints.maxWidth - AppSpacing.small) / 2,
              child: button,
            );
          }).toList(),
        );
      },
    );
  }
}

class _RankedResultTile extends StatelessWidget {
  const _RankedResultTile({required this.result, required this.selected});

  final RestaurantResult result;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: selected
            ? colors.primaryContainer
            : colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(
          color: selected
              ? colors.primary.withValues(alpha: 0.34)
              : colors.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          _RankNumber(rank: result.rank),
          const SizedBox(width: AppSpacing.medium),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.small),
            child: SizedBox.square(
              dimension: 64,
              child: RestaurantImage(
                imageUrl: result.restaurant.imageUrl,
                semanticLabel: '${result.restaurant.name}の料理写真',
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.medium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        result.restaurant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (result.isUnanimous) const _SmallBadge(label: '全員一致'),
                  ],
                ),
                const SizedBox(height: AppSpacing.micro),
                Text(
                  '${result.likeCount}いいね  ·  ${result.rejectCount}拒否  ·  ${(result.likeRate * 100).round()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  child: LinearProgressIndicator(
                    value: result.likeRate,
                    minHeight: AppSizes.progressIndicatorHeight,
                    backgroundColor: colors.surfaceContainerHigh,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      selected ? colors.primary : colors.secondary,
                    ),
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

class _RankNumber extends StatelessWidget {
  const _RankNumber({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: rank == 1 ? colors.primary : colors.surfaceContainerHigh,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$rank',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: rank == 1 ? colors.onPrimary : colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors.onPrimary, size: AppSizes.iconMedium),
          const SizedBox(width: AppSpacing.small),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: colors.onPrimary),
          ),
        ],
      ),
    );
  }
}

class _UnanimousBadge extends StatelessWidget {
  const _UnanimousBadge();

  @override
  Widget build(BuildContext context) {
    return const _SmallBadge(label: '全員一致');
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.small,
        vertical: AppSpacing.micro,
      ),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colors.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _VoteMetric extends StatelessWidget {
  const _VoteMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Column(
        children: [
          Text(value, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.micro),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) {
      return;
    }

    final paint = Paint();
    const colors = [
      Color(0xFFEF5B3F),
      Color(0xFF2E7D6F),
      Color(0xFFF2C94C),
      Color(0xFF4A90E2),
    ];

    for (var index = 0; index < 26; index++) {
      final seed = index * 37.0;
      final x = (math.sin(seed) * 0.5 + 0.5) * size.width;
      final y =
          (progress * size.height * 0.55) + (math.cos(seed * 0.7) * 26) - 48;
      final opacity = (1 - progress).clamp(0, 1).toDouble();
      paint.color = colors[index % colors.length].withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(seed + progress * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-4, -7, 8, 14),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

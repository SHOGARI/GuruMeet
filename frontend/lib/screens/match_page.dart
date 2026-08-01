import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/group_creation_draft.dart';
import '../models/restaurant_preview.dart';
import '../models/result_summary.dart';
import '../services/room_repository.dart';
import '../services/user_error_messages.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_shell.dart';
import '../widgets/group_code_badge.dart';
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
  final RoomRepository _roomRepository = RoomRepositoryProvider.instance;

  late final ResultSummary _summary;
  late RestaurantResult _selectedResult;
  late final AnimationController _controller;
  Timer? _decisionTimer;
  bool _isNavigating = false;
  bool _isOpeningMaps = false;
  bool _isConfirmingDecision = false;
  late bool _isTieDecided;

  bool get _isFinalDecision => !_summary.hasTie || _isTieDecided;
  bool get _canChooseTieWinner => _summary.hasTie && widget.draft.isHost;
  RestaurantPreview get restaurant => _selectedResult.restaurant;

  @override
  void initState() {
    super.initState();
    _summary = ResultSummary.fromMatchResult(widget.result);
    _selectedResult = _summary.rankedResults.firstWhere(
      (result) => result.restaurant.id == widget.result.restaurant.id,
      orElse: () => _summary.winner,
    );
    _isTieDecided =
        _summary.hasTie && widget.result.decidedRestaurantId != null;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    if (_isFinalDecision) {
      _controller.forward();
    } else {
      _startDecisionPolling();
    }
  }

  @override
  void dispose() {
    _decisionTimer?.cancel();
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

  void _selectTieResult(RestaurantResult result) {
    if (!_canChooseTieWinner || _isTieDecided || result.rank != 1) {
      return;
    }

    setState(() => _selectedResult = result);
  }

  Future<void> _confirmRestaurant() async {
    if (!_canChooseTieWinner || _isTieDecided || _isConfirmingDecision) {
      return;
    }

    setState(() => _isConfirmingDecision = true);
    try {
      final result = await _roomRepository.decideTiedWinner(
        draft: widget.draft,
        restaurantId: _selectedResult.restaurant.id,
        restaurants: _summary.rankedResults
            .map((result) => result.restaurant)
            .toList(),
        localChoices: const [],
      );
      if (!mounted) {
        return;
      }
      _applyDecidedResult(result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(votingErrorMessage(error))));
    } finally {
      if (mounted) {
        setState(() => _isConfirmingDecision = false);
      }
    }
  }

  void _startDecisionPolling() {
    if (widget.draft.roomId == null) {
      return;
    }
    _decisionTimer?.cancel();
    _decisionTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (!mounted || _isTieDecided) {
        _decisionTimer?.cancel();
        return;
      }
      unawaited(_loadDecision());
    });
  }

  Future<void> _loadDecision() async {
    try {
      final result = await _roomRepository.getResult(
        draft: widget.draft,
        restaurants: _summary.rankedResults
            .map((result) => result.restaurant)
            .toList(),
        localChoices: const [],
      );
      if (!mounted || result.decidedRestaurantId == null) {
        return;
      }
      _applyDecidedResult(result);
    } catch (_) {
      return;
    }
  }

  void _applyDecidedResult(RestaurantMatchResult result) {
    final selected = _summary.rankedResults.firstWhere(
      (rankedResult) => rankedResult.restaurant.id == result.restaurant.id,
      orElse: () => _selectedResult,
    );
    setState(() {
      _selectedResult = selected;
      _isTieDecided = true;
    });
    _decisionTimer?.cancel();
    _controller.forward(from: 0);
  }

  void _restartVoting() {
    if (_isNavigating) {
      return;
    }
    setState(() => _isNavigating = true);
    Navigator.of(
      context,
    ).pushReplacementNamed(SwipePage.routeName, arguments: widget.draft);
  }

  Future<void> _openDetail() async {
    if (_isNavigating) {
      return;
    }
    setState(() => _isNavigating = true);
    await Navigator.of(context).pushNamed(
      RestaurantDetailPage.routeName,
      arguments: (draft: widget.draft, restaurant: restaurant),
    );
    if (mounted) {
      setState(() => _isNavigating = false);
    }
  }

  void _goHome() {
    if (_isNavigating) {
      return;
    }
    setState(() => _isNavigating = true);
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(HomePage.routeName, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope<void>(
      canPop: false,
      child: AppShell(
        appBar: AppBar(
          title: const Text('結果'),
          automaticallyImplyLeading: false,
          actions: [GroupCodeBadge(code: widget.draft.groupId)],
        ),
        maxContentWidth: AppSizes.homeMaxWidth,
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
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
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ResultHeader(
                  summary: _summary,
                  selectedResult: _selectedResult,
                  isFinalDecision: _isFinalDecision,
                ),
                const SizedBox(height: AppSpacing.large),
                ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1).animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: const Interval(0, 0.55, curve: Curves.easeOutBack),
                    ),
                  ),
                  child: _WinnerCard(
                    result: _selectedResult,
                    hasTie: _summary.hasTie,
                    isFinalDecision: _isFinalDecision,
                  ),
                ),
                const SizedBox(height: AppSpacing.large),
                _ResultActions(
                  hasTie: _summary.hasTie && !_isFinalDecision,
                  canRestart: widget.draft.roomId == null,
                  onOpenMaps: _isOpeningMaps || _isNavigating
                      ? null
                      : _openMaps,
                  onConfirm:
                      _canChooseTieWinner &&
                          !_isFinalDecision &&
                          !_isConfirmingDecision
                      ? _confirmRestaurant
                      : null,
                  onRestart: _isNavigating ? null : _restartVoting,
                  onOpenDetail: _isNavigating ? null : _openDetail,
                  onGoHome: _isNavigating ? null : _goHome,
                ),
                const SizedBox(height: AppSpacing.xLarge),
                Text('ランキング', style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.medium),
                ..._summary.podiumResults.map(
                  (result) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.regular),
                    child: _RankedResultTile(
                      key: ValueKey('ranked-result-${result.restaurant.id}'),
                      result: result,
                      selected:
                          result.restaurant.id == _selectedResult.restaurant.id,
                      enabled:
                          _canChooseTieWinner &&
                          !_isTieDecided &&
                          result.rank == 1,
                      onTap: () => _selectTieResult(result),
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
                            key: ValueKey(
                              'ranked-result-${result.restaurant.id}',
                            ),
                            result: result,
                            selected:
                                result.restaurant.id ==
                                _selectedResult.restaurant.id,
                            enabled:
                                _canChooseTieWinner &&
                                !_isTieDecided &&
                                result.rank == 1,
                            onTap: () => _selectTieResult(result),
                          ),
                        ),
                      ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({
    required this.summary,
    required this.selectedResult,
    required this.isFinalDecision,
  });

  final ResultSummary summary;
  final RestaurantResult selectedResult;
  final bool isFinalDecision;

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
            isFinalDecision ? "IT'S A MATCH" : 'FINAL ROUND',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.onPrimaryContainer,
              letterSpacing: AppSizes.codeLabelLetterSpacing,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.medium),
        Text(
          isFinalDecision ? '今日のお店が決定。' : '同率1位。候補を選択。',
          style: theme.textTheme.headlineLarge,
        ),
        const SizedBox(height: AppSpacing.small),
        Text(
          isFinalDecision
              ? '${selectedResult.likeCount} / ${summary.peopleCount}人が「行きたい」を選びました。'
              : '話し合って、ホストが決定してください。',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _WinnerCard extends StatelessWidget {
  const _WinnerCard({
    required this.result,
    required this.hasTie,
    required this.isFinalDecision,
  });

  final RestaurantResult result;
  final bool hasTie;
  final bool isFinalDecision;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final restaurant = result.restaurant;

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
                aspectRatio: 1.9,
                child: RestaurantImage(
                  key: ValueKey('winner-image-${restaurant.id}'),
                  imageUrl: restaurant.imageUrl,
                  semanticLabel: '${restaurant.name}の料理写真',
                ),
              ),
              Positioned(
                left: AppSpacing.medium,
                top: AppSpacing.medium,
                child: _RankBadge(
                  label: hasTie ? '同率1位' : '1位',
                  icon: Icons.workspace_premium_rounded,
                ),
              ),
              if (result.isUnanimous)
                const Positioned(
                  right: AppSpacing.medium,
                  top: AppSpacing.medium,
                  child: _UnanimousBadge(),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFinalDecision ? 'この店に決定' : '選択中の候補',
                  style: theme.textTheme.titleMedium,
                ),
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
                const SizedBox(height: AppSpacing.medium),
                Row(
                  children: [
                    Expanded(
                      child: _VoteMetric(
                        label: '行きたい',
                        value: '${result.likeCount}',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Expanded(
                      child: _VoteMetric(
                        label: '見送り',
                        value: '${result.rejectCount}',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Expanded(
                      child: _VoteMetric(
                        label: '支持率',
                        value: '${(result.likeRate * 100).round()}%',
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
    required this.canRestart,
    required this.onOpenMaps,
    required this.onConfirm,
    required this.onRestart,
    required this.onOpenDetail,
    required this.onGoHome,
  });

  final bool hasTie;
  final bool canRestart;
  final VoidCallback? onOpenMaps;
  final VoidCallback? onConfirm;
  final VoidCallback? onRestart;
  final VoidCallback? onOpenDetail;
  final VoidCallback? onGoHome;

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
          if (onConfirm != null)
            FilledButton.tonalIcon(
              onPressed: onConfirm,
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('この店に決定'),
            ),
          if (canRestart)
            OutlinedButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('もう一度選ぶ'),
            ),
          OutlinedButton(onPressed: onOpenDetail, child: const Text('店舗詳細を見る')),
          TextButton(onPressed: onGoHome, child: const Text('ホームへ戻る')),
        ];

        Widget actions;
        if (constraints.maxWidth < 620) {
          actions = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < buttons.length; index++) ...[
                if (index > 0) const SizedBox(height: AppSpacing.small),
                buttons[index],
              ],
            ],
          );
        } else {
          actions = Wrap(
            spacing: AppSpacing.small,
            runSpacing: AppSpacing.small,
            children: buttons.map((button) {
              return SizedBox(
                width: (constraints.maxWidth - AppSpacing.small) / 2,
                child: button,
              );
            }).toList(),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasTie) ...[
              _TieNotice(onRestart: canRestart ? onRestart : null),
              const SizedBox(height: AppSpacing.small),
            ],
            actions,
          ],
        );
      },
    );
  }
}

class _TieNotice extends StatelessWidget {
  const _TieNotice({required this.onRestart});

  final VoidCallback? onRestart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        children: [
          Icon(Icons.how_to_vote_rounded, color: colors.primary),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Text(
              onRestart == null
                  ? '同率候補があります。ランキングから候補を確認してください。'
                  : '同率候補から選んでください。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (onRestart != null)
            TextButton(onPressed: onRestart, child: const Text('選び直す')),
        ],
      ),
    );
  }
}

class _RankedResultTile extends StatelessWidget {
  const _RankedResultTile({
    super.key,
    required this.result,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final RestaurantResult result;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.small),
        side: BorderSide(
          color: selected
              ? colors.primary.withValues(alpha: 0.42)
              : colors.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.medium),
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
                        if (selected && enabled)
                          const _SmallBadge(label: '選択中'),
                        if ((!selected || !enabled) && result.isUnanimous)
                          const _SmallBadge(label: '全員一致'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.micro),
                    Text(
                      '${result.likeCount}人が行きたい  ·  ${result.rejectCount}人が見送り  ·  ${(result.likeRate * 100).round()}%',
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
              if (enabled) ...[
                const SizedBox(width: AppSpacing.small),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/group_creation_draft.dart';
import '../theme/app_tokens.dart';
import '../widgets/primary_action_button.dart';
import 'swipe_page.dart';

class WaitingRoomPage extends StatefulWidget {
  const WaitingRoomPage({super.key, required this.draft});

  static const routeName = '/waiting-room';

  final GroupCreationDraft draft;

  @override
  State<WaitingRoomPage> createState() => _WaitingRoomPageState();
}

class _WaitingRoomPageState extends State<WaitingRoomPage> {
  bool _isNavigating = f
  alse;
  int _joinedCount = 1;

  bool get _isGroupReady => _joinedCount == widget.draft.peopleCount;

  void _addParticipant() {
    if (_isGroupReady) {
      return;
    }
    setState(() => _joinedCount++);
  }

  Future<void> _startSwipe() async {
    if (_isNavigating || !_isGroupReady) {
      return;
    }
    setState(() => _isNavigating = true);
    await Navigator.of(
      context,
    ).pushNamed(SwipePage.routeName, arguments: widget.draft);
    if (mounted) {
      setState(() => _isNavigating = false);
    }
  }

  Future<void> _copyUrl() async {
    await Clipboard.setData(ClipboardData(text: widget.draft.inviteUrl));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('招待URLをコピーしました')));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < AppBreakpoints.compact
        ? AppSpacing.large
        : AppSpacing.xLarge;

    return Scaffold(
      appBar: AppBar(title: const Text('メンバー待機')),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.large,
            horizontalPadding,
            AppSpacing.large,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.contentMaxWidth,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _WaitingHero(
                            joinedCount: _joinedCount,
                            peopleCount: widget.draft.peopleCount,
                          ),
                          const SizedBox(height: AppSpacing.section),
                          _InviteCard(draft: widget.draft, onCopyUrl: _copyUrl),
                          const SizedBox(height: AppSpacing.section),
                          _MemberSlots(
                            joinedCount: _joinedCount,
                            peopleCount: widget.draft.peopleCount,
                          ),
                          const SizedBox(height: AppSpacing.large),
                          _DemoJoinPanel(
                            isGroupReady: _isGroupReady,
                            onAddParticipant: _addParticipant,
                          ),
                          const SizedBox(height: AppSpacing.section),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.regular),
                  _StartHint(
                    joinedCount: _joinedCount,
                    peopleCount: widget.draft.peopleCount,
                  ),
                  const SizedBox(height: AppSpacing.regular),
                  PrimaryActionButton(
                    label: _isGroupReady ? 'お店選びを始める' : '全員がそろうと開始できます',
                    onPressed: _isNavigating || !_isGroupReady
                        ? null
                        : _startSwipe,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WaitingHero extends StatelessWidget {
  const _WaitingHero({required this.joinedCount, required this.peopleCount});

  final int joinedCount;
  final int peopleCount;

  double get _progress => joinedCount / peopleCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final remainingCount = peopleCount - joinedCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xLarge),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.elevatedAction(colors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            remainingCount == 0 ? 'READY' : 'WAITING',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onPrimary.withValues(alpha: 0.72),
              letterSpacing: AppSizes.codeLabelLetterSpacing,
            ),
          ),
          const SizedBox(height: AppSpacing.regular),
          Text(
            remainingCount == 0 ? '全員そろいました。' : 'あと$remainingCount人で\n始められます。',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: colors.onPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xLarge),
          _PeoplePulseRow(joinedCount: joinedCount, peopleCount: peopleCount),
          const SizedBox(height: AppSpacing.xLarge),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$joinedCount',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: colors.onPrimary,
                  height: 0.95,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.small,
                  bottom: AppSpacing.small,
                ),
                child: Text(
                  '/ $peopleCount 人',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colors.onPrimary.withValues(alpha: 0.82),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            '$joinedCount / $peopleCount人',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onPrimary.withValues(alpha: 0.86),
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: _progress),
              duration: AppMotion.medium,
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: AppSizes.progressIndicatorHeight,
                  backgroundColor: colors.onPrimary.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(colors.onPrimary),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PeoplePulseRow extends StatelessWidget {
  const _PeoplePulseRow({required this.joinedCount, required this.peopleCount});

  final int joinedCount;
  final int peopleCount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.small,
      runSpacing: AppSpacing.small,
      children: List.generate(peopleCount, (index) {
        final isJoined = index < joinedCount;
        return AnimatedScale(
          key: ValueKey('person-$index-$isJoined'),
          scale: isJoined ? 1 : 0.92,
          duration: AppMotion.medium,
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: isJoined ? 1 : 0.42,
            duration: AppMotion.medium,
            curve: Curves.easeOutCubic,
            child: _PersonDot(isJoined: isJoined),
          ),
        );
      }),
    );
  }
}

class _PersonDot extends StatelessWidget {
  const _PersonDot({required this.isJoined});

  final bool isJoined;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: AppSizes.touchTarget,
      height: AppSizes.touchTarget,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isJoined
            ? colors.onPrimary
            : colors.onPrimary.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(
          color: colors.onPrimary.withValues(alpha: isJoined ? 0 : 0.38),
        ),
      ),
      child: Icon(
        Icons.person_rounded,
        size: AppSizes.iconMedium,
        color: isJoined ? colors.primary : colors.onPrimary,
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.draft, required this.onCopyUrl});

  final GroupCreationDraft draft;
  final VoidCallback onCopyUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.large),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.64),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('招待コード', style: theme.textTheme.titleLarge)),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.regular,
                  vertical: AppSpacing.small,
                ),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: SelectableText(
                  draft.groupId,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                    letterSpacing: AppSizes.groupCodeLetterSpacing,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.large),
          Text(
            '招待URL',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          SelectableText(
            draft.inviteUrl,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: onCopyUrl,
              icon: const Icon(Icons.copy_rounded, size: AppSizes.iconMedium),
              label: const Text('招待リンクをコピー'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberSlots extends StatelessWidget {
  const _MemberSlots({required this.joinedCount, required this.peopleCount});

  final int joinedCount;
  final int peopleCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('参加メンバー', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.medium),
        ...List.generate(peopleCount, (index) {
          final isJoined = index < joinedCount;
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == peopleCount - 1 ? 0 : AppSpacing.regular,
            ),
            child: _MemberSlot(index: index, isJoined: isJoined),
          );
        }),
      ],
    );
  }
}

class _MemberSlot extends StatelessWidget {
  const _MemberSlot({required this.index, required this.isJoined});

  final int index;
  final bool isJoined;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isHost = index == 0;

    return AnimatedSwitcher(
      duration: AppMotion.medium,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      child: AnimatedContainer(
        key: ValueKey('member-$index-$isJoined'),
        duration: AppMotion.medium,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(AppSpacing.medium),
        decoration: BoxDecoration(
          color: isJoined
              ? colors.surfaceContainerLowest
              : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(
            color: isJoined
                ? colors.primary.withValues(alpha: 0.32)
                : colors.outlineVariant.withValues(alpha: 0.56),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: AppSizes.touchTarget / 2,
              backgroundColor: isJoined
                  ? colors.primaryContainer
                  : colors.surfaceContainerHighest,
              foregroundColor: isJoined
                  ? colors.primary
                  : colors.onSurfaceVariant,
              child: Icon(
                isHost
                    ? Icons.star_rounded
                    : (isJoined
                          ? Icons.person_rounded
                          : Icons.schedule_rounded),
              ),
            ),
            const SizedBox(width: AppSpacing.regular),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          isJoined
                              ? (isHost ? 'あなた' : '参加者 ${index + 1}')
                              : '招待待ち',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (isHost) ...[
                        const SizedBox(width: AppSpacing.small),
                        const _MemberLabel(label: 'ホスト'),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.micro),
                  Text(
                    isJoined ? '参加済み' : 'リンクから参加するとここに表示されます',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.small),
            _MemberLabel(label: isJoined ? '参加済み' : '待機中'),
          ],
        ),
      ),
    );
  }
}

class _MemberLabel extends StatelessWidget {
  const _MemberLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isWaiting = label == '待機中';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.small,
        vertical: AppSpacing.micro,
      ),
      decoration: BoxDecoration(
        color: isWaiting
            ? colors.surfaceContainerHighest
            : colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isWaiting
              ? colors.onSurfaceVariant
              : colors.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StartHint extends StatelessWidget {
  const _StartHint({required this.joinedCount, required this.peopleCount});

  final int joinedCount;
  final int peopleCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final remainingCount = peopleCount - joinedCount;

    return AnimatedSwitcher(
      duration: AppMotion.medium,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: Text(
        remainingCount == 0
            ? '全員そろいました。店選びを始めましょう。'
            : 'あと$remainingCount人参加すると開始できます',
        key: ValueKey(remainingCount),
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: remainingCount == 0 ? colors.primary : colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DemoJoinPanel extends StatelessWidget {
  const _DemoJoinPanel({
    required this.isGroupReady,
    required this.onAddParticipant,
  });

  final bool isGroupReady;
  final VoidCallback onAddParticipant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (isGroupReady) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.medium),
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: colors.primary),
            const SizedBox(width: AppSpacing.small),
            Expanded(
              child: Text(
                '全員そろいました。ホストがお店選びを開始できます。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: onAddParticipant,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('招待URLから参加（デモ）'),
          ),
        ),
        const SizedBox(height: AppSpacing.regular),
        Text(
          'バックエンド未接続のため、URLからの参加はこのボタンで再現しています。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

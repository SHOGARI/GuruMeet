import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/group_creation_draft.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_shell.dart';
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
  bool _isNavigating = false;
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AppShell(
      appBar: AppBar(title: const Text('メンバー待機')),
      bottomBar: PrimaryActionButton(
        label: _isGroupReady ? 'お店選びを始める' : '全員がそろうと開始できます',
        onPressed: _isNavigating || !_isGroupReady ? null : _startSwipe,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'みんながそろうまで\nあと少し。',
                  style: theme.textTheme.headlineLarge,
                ),
              ),
              _JoinedCount(
                joinedCount: _joinedCount,
                peopleCount: widget.draft.peopleCount,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.regular),
          Text(
            'URLを送ったら、あとは集まるのを待つだけ。',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          Text('招待リンク', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.small),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.medium),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: SelectableText(
              widget.draft.inviteUrl,
              style: theme.textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          TextButton.icon(
            onPressed: _copyUrl,
            icon: const Icon(Icons.copy_rounded, size: AppSizes.iconMedium),
            label: const Text('リンクをコピー'),
          ),
          const SizedBox(height: AppSpacing.section),
          Row(
            children: [
              Expanded(
                child: Text('参加メンバー', style: theme.textTheme.titleLarge),
              ),
              Text(
                '${widget.draft.area}  ·  ${widget.draft.budget.label}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.medium),
          ...List.generate(_joinedCount, (index) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == _joinedCount - 1 ? 0 : AppSpacing.regular,
              ),
              child: _MemberRow(index: index),
            );
          }),
          const SizedBox(height: AppSpacing.large),
          if (!_isGroupReady)
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _addParticipant,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('招待URLから参加（デモ）'),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.medium),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Text(
                '全員そろいました。ホストがお店選びを開始できます。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onPrimaryContainer,
                ),
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
      ),
    );
  }
}

class _JoinedCount extends StatelessWidget {
  const _JoinedCount({required this.joinedCount, required this.peopleCount});

  final int joinedCount;
  final int peopleCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Text(
        '$joinedCount / $peopleCount人',
        style: theme.textTheme.titleSmall?.copyWith(
          color: colors.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isHost = index == 0;

    return Row(
      children: [
        CircleAvatar(
          radius: AppSizes.touchTarget / 2,
          backgroundColor: isHost
              ? colors.primaryContainer
              : colors.surfaceContainerHigh,
          foregroundColor: isHost ? colors.primary : colors.onSurfaceVariant,
          child: Text(isHost ? '自' : '${index + 1}'),
        ),
        const SizedBox(width: AppSpacing.regular),
        Expanded(
          child: Text(
            isHost ? 'あなた（ホスト）' : '参加者 ${index + 1}',
            style: theme.textTheme.titleMedium,
          ),
        ),
        Text(
          '参加済み',
          style: theme.textTheme.bodySmall?.copyWith(color: colors.primary),
        ),
      ],
    );
  }
}

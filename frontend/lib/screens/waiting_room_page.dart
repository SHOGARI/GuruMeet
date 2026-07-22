import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/group_creation_draft.dart';
import '../models/room_member.dart';
import '../services/mock_room_service.dart';
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
  static const _roomService = MockRoomService();

  late List<RoomMember> _members;
  Timer? _joinTimer;
  bool _isNavigating = false;

  bool get _isHost => _members.any((member) => member.isHost);
  bool get _isRoomReady =>
      _members.length == widget.draft.peopleCount &&
      _members.every((member) => member.isReady);

  @override
  void initState() {
    super.initState();
    _members = _roomService.initialWaitingMembers(
      peopleCount: widget.draft.peopleCount,
    );
    _joinTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      _addDemoMember();
    });
  }

  @override
  void dispose() {
    _joinTimer?.cancel();
    super.dispose();
  }

  void _addDemoMember() {
    if (!mounted) {
      return;
    }
    final nextMember = _roomService.nextWaitingMember(
      currentMembers: _members,
      peopleCount: widget.draft.peopleCount,
    );
    if (nextMember == null) {
      _joinTimer?.cancel();
      return;
    }
    setState(() => _members = [..._members, nextMember]);
  }

  Future<void> _startSwipe() async {
    if (_isNavigating || !_isRoomReady) {
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

  Future<void> _copyRoomCode() async {
    await Clipboard.setData(ClipboardData(text: widget.draft.groupId));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('ルームコードをコピーしました')));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < AppBreakpoints.compact
        ? AppSpacing.medium
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
                          _RoomCodePanel(
                            draft: widget.draft,
                            joinedCount: _members.length,
                            onCopyRoomCode: _copyRoomCode,
                          ),
                          const SizedBox(height: AppSpacing.section),
                          _MemberList(
                            members: _members,
                            peopleCount: widget.draft.peopleCount,
                          ),
                          const SizedBox(height: AppSpacing.large),
                          _WaitingNote(isReady: _isRoomReady),
                          const SizedBox(height: AppSpacing.section),
                        ],
                      ),
                    ),
                  ),
                  if (_isHost) ...[
                    _StartHint(
                      joinedCount: _members.length,
                      peopleCount: widget.draft.peopleCount,
                      isReady: _isRoomReady,
                    ),
                    const SizedBox(height: AppSpacing.regular),
                    PrimaryActionButton(
                      label: '投票を開始',
                      onPressed: _isNavigating || !_isRoomReady
                          ? null
                          : _startSwipe,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomCodePanel extends StatelessWidget {
  const _RoomCodePanel({
    required this.draft,
    required this.joinedCount,
    required this.onCopyRoomCode,
  });

  final GroupCreationDraft draft;
  final int joinedCount;
  final VoidCallback onCopyRoomCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
            joinedCount == draft.peopleCount ? 'READY' : 'WAITING',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onPrimary.withValues(alpha: 0.72),
              letterSpacing: AppSizes.codeLabelLetterSpacing,
            ),
          ),
          const SizedBox(height: AppSpacing.regular),
          Text(
            'ルームコード',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onPrimary.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          SelectableText(
            draft.groupId,
            style: theme.textTheme.displaySmall?.copyWith(
              color: colors.onPrimary,
              letterSpacing: AppSizes.groupCodeLetterSpacing,
              height: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.large),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 270;
              final copyButton = SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: onCopyRoomCode,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('コピー'),
                ),
              );
              final qrCode = Align(
                alignment: isNarrow ? Alignment.centerLeft : Alignment.center,
                child: _QrPlaceholder(
                  code: draft.groupId,
                  size: constraints.maxWidth < 360 ? 104 : AppSizes.qrCodeSize,
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    copyButton,
                    const SizedBox(height: AppSpacing.medium),
                    qrCode,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: copyButton),
                  const SizedBox(width: AppSpacing.medium),
                  qrCode,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.medium),
          Text(
            '$joinedCount / ${draft.peopleCount}人',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onPrimary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: AppSpacing.regular),
          SelectableText(
            draft.inviteUrl,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onPrimary.withValues(alpha: 0.82),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QrPlaceholder extends StatelessWidget {
  const _QrPlaceholder({required this.code, required this.size});

  final String code;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(AppSpacing.small),
      decoration: BoxDecoration(
        color: colors.onPrimary,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: 49,
        itemBuilder: (context, index) {
          final filled =
              (index + code.codeUnitAt(index % code.length)) % 3 != 0;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: filled ? colors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        },
      ),
    );
  }
}

class _MemberList extends StatelessWidget {
  const _MemberList({required this.members, required this.peopleCount});

  final List<RoomMember> members;
  final int peopleCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('参加メンバー', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.medium),
        AnimatedListLikeColumn(
          children: List.generate(peopleCount, (index) {
            final member = index < members.length ? members[index] : null;
            return _MemberTile(
              key: ValueKey(member?.id ?? 'empty-$index'),
              member: member,
              index: index,
            );
          }),
        ),
      ],
    );
  }
}

class AnimatedListLikeColumn extends StatelessWidget {
  const AnimatedListLikeColumn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < children.length; index++)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == children.length - 1 ? 0 : AppSpacing.regular,
            ),
            child: AnimatedSwitcher(
              duration: AppMotion.medium,
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: children[index],
            ),
          ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({super.key, required this.member, required this.index});

  final RoomMember? member;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final activeMember = member;
    final isJoined = activeMember != null;

    return Container(
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
          _MemberAvatar(member: activeMember, index: index),
          const SizedBox(width: AppSpacing.regular),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        activeMember?.name ?? '招待待ち',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (activeMember?.isHost ?? false) ...[
                      const SizedBox(width: AppSpacing.small),
                      const _MemberBadge(label: 'ホスト'),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.micro),
                Text(
                  isJoined ? '準備完了' : 'リンクから参加するとここに表示されます',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.small),
          _MemberBadge(label: isJoined ? '準備OK' : '待機中'),
        ],
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.member, required this.index});

  final RoomMember? member;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final activeMember = member;
    final isJoined = activeMember != null;

    return CircleAvatar(
      radius: AppSizes.touchTarget / 2,
      backgroundColor: isJoined
          ? colors.primaryContainer
          : colors.surfaceContainerHighest,
      foregroundColor: isJoined ? colors.primary : colors.onSurfaceVariant,
      backgroundImage: activeMember?.avatarUrl == null
          ? null
          : NetworkImage(activeMember!.avatarUrl!),
      child: activeMember?.avatarUrl == null
          ? Icon(
              activeMember?.isHost ?? false
                  ? Icons.star_rounded
                  : (isJoined ? Icons.person_rounded : Icons.schedule_rounded),
            )
          : null,
    );
  }
}

class _MemberBadge extends StatelessWidget {
  const _MemberBadge({required this.label});

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

class _WaitingNote extends StatelessWidget {
  const _WaitingNote({required this.isReady});

  final bool isReady;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: isReady ? colors.primaryContainer : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Text(
        isReady ? '全員の準備が完了しました。ホストが投票を開始できます。' : 'デモでは数秒ごとに疑似メンバーが参加します。',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isReady ? colors.onPrimaryContainer : colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StartHint extends StatelessWidget {
  const _StartHint({
    required this.joinedCount,
    required this.peopleCount,
    required this.isReady,
  });

  final int joinedCount;
  final int peopleCount;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final remainingCount = peopleCount - joinedCount;

    return AnimatedSwitcher(
      duration: AppMotion.medium,
      child: Text(
        isReady ? '全員そろいました。投票を始めましょう。' : 'あと$remainingCount人で開始できます',
        key: ValueKey('$remainingCount-$isReady'),
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isReady ? colors.primary : colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

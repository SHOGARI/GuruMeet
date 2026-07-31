import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/group_creation_draft.dart';
import '../models/room_member.dart';
import '../services/room_repository.dart';
import '../services/user_error_messages.dart';
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
  final RoomRepository _roomRepository = RoomRepositoryProvider.instance;

  List<RoomMember> _members = const [];
  Timer? _joinTimer;
  bool _isNavigating = false;
  bool _isLoadingMembers = true;
  bool _isVotingStarted = false;
  String? _memberLoadError;
  DateTime? _lastMemberLoadedAt;

  bool get _isHost => widget.draft.isHost;
  bool get _isRoomReady =>
      _members.length == widget.draft.peopleCount &&
      _members.every((member) => member.isReady);

  @override
  void initState() {
    super.initState();
    unawaited(_loadMembers());
    _joinTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      unawaited(_loadMembers(showLoading: false));
    });
  }

  @override
  void dispose() {
    _joinTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMembers({bool showLoading = true}) async {
    if (!mounted) {
      return;
    }
    if (showLoading) {
      setState(() {
        _isLoadingMembers = true;
        _memberLoadError = null;
      });
    }
    try {
      final members = await _roomRepository.getMembers(widget.draft);
      final votingStarted = _isHost
          ? _isVotingStarted
          : await _roomRepository.isVotingStarted(widget.draft);
      if (!mounted) {
        return;
      }
      setState(() {
        _members = members;
        _isVotingStarted = votingStarted;
        _isLoadingMembers = false;
        _memberLoadError = null;
        _lastMemberLoadedAt = DateTime.now();
      });
      if ((_isHost && _isRoomReady) || (!_isHost && votingStarted)) {
        _joinTimer?.cancel();
      }
      if (!_isHost && votingStarted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('投票が始まりました')));
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingMembers = false;
        _memberLoadError = votingErrorMessage(error);
      });
    }
  }

  Future<void> _startSwipe() async {
    if (_isNavigating || !_isRoomReady) {
      return;
    }
    setState(() => _isNavigating = true);
    try {
      await _roomRepository.startVoting(widget.draft);
      if (!mounted) {
        return;
      }
      await Navigator.of(
        context,
      ).pushReplacementNamed(SwipePage.routeName, arguments: widget.draft);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(votingErrorMessage(error))));
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }

  Future<void> _enterSwipe() async {
    if (_isNavigating || !_isVotingStarted) {
      return;
    }
    setState(() => _isNavigating = true);
    await Navigator.of(
      context,
    ).pushReplacementNamed(SwipePage.routeName, arguments: widget.draft);
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
            AppSpacing.regular,
            horizontalPadding,
            AppSpacing.regular,
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
                          const SizedBox(height: AppSpacing.large),
                          _MemberList(
                            members: _members,
                            peopleCount: widget.draft.peopleCount,
                            isLoading: _isLoadingMembers,
                            errorMessage: _memberLoadError,
                            lastUpdatedAt: _lastMemberLoadedAt,
                            onRetry: () => unawaited(_loadMembers()),
                          ),
                          const SizedBox(height: AppSpacing.medium),
                          _WaitingNote(isReady: _isRoomReady, isHost: _isHost),
                          const SizedBox(height: AppSpacing.large),
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
                  ] else ...[
                    _ParticipantVotingHint(isVotingStarted: _isVotingStarted),
                    const SizedBox(height: AppSpacing.regular),
                    PrimaryActionButton(
                      label: '投票画面へ進む',
                      onPressed: _isNavigating || !_isVotingStarted
                          ? null
                          : _enterSwipe,
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
      padding: const EdgeInsets.all(AppSpacing.medium),
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
          const SizedBox(height: AppSpacing.small),
          Text(
            'ルームコード',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onPrimary.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: AppSpacing.micro),
          SelectableText(
            draft.groupId,
            style: theme.textTheme.displaySmall?.copyWith(
              color: colors.onPrimary,
              letterSpacing: AppSizes.groupCodeLetterSpacing,
              height: 0.95,
              fontSize: 42,
            ),
          ),
          const SizedBox(height: AppSpacing.regular),
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
                  value: draft.inviteUrl,
                  size: constraints.maxWidth < 360 ? 92 : 108,
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
          const SizedBox(height: AppSpacing.small),
          Text(
            '$joinedCount / ${draft.peopleCount}人',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onPrimary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: AppSpacing.micro),
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
  const _QrPlaceholder({required this.value, required this.size});

  final String value;
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
      child: QrImageView(
        data: value,
        version: QrVersions.auto,
        gapless: false,
        padding: EdgeInsets.zero,
        backgroundColor: colors.onPrimary,
        eyeStyle: QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: colors.primary,
        ),
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: colors.primary,
        ),
      ),
    );
  }
}

class _MemberList extends StatelessWidget {
  const _MemberList({
    required this.members,
    required this.peopleCount,
    required this.isLoading,
    required this.errorMessage,
    required this.lastUpdatedAt,
    required this.onRetry,
  });

  final List<RoomMember> members;
  final int peopleCount;
  final bool isLoading;
  final String? errorMessage;
  final DateTime? lastUpdatedAt;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('参加メンバー', style: theme.textTheme.titleLarge)),
            if (lastUpdatedAt != null)
              Text(
                '更新 ${_formatTime(lastUpdatedAt!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.regular),
        if (isLoading) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: AppSpacing.regular),
        ],
        if (errorMessage case final message?) ...[
          _InlineNotice(
            icon: Icons.error_outline_rounded,
            message: message,
            actionLabel: '再読み込み',
            onAction: onRetry,
          ),
          const SizedBox(height: AppSpacing.regular),
        ] else if (!isLoading && members.isEmpty) ...[
          const _InlineNotice(
            icon: Icons.people_outline_rounded,
            message: 'まだ参加者がいません',
          ),
          const SizedBox(height: AppSpacing.regular),
        ],
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

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          if (actionLabel case final label?) ...[
            const SizedBox(width: AppSpacing.small),
            TextButton(onPressed: onAction, child: Text(label)),
          ],
        ],
      ),
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
              bottom: index == children.length - 1 ? 0 : AppSpacing.small,
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.regular,
      ),
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
                    if (activeMember?.isMe ?? false) ...[
                      const SizedBox(width: AppSpacing.small),
                      const _MemberBadge(label: 'あなた'),
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
  const _WaitingNote({required this.isReady, required this.isHost});

  final bool isReady;
  final bool isHost;

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
        isReady
            ? (isHost ? '全員そろいました。投票を開始できます。' : '全員そろいました。ホストの開始を待っています。')
            : '招待URLやQRコードから参加すると、ここにメンバーが表示されます。',
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

class _ParticipantVotingHint extends StatelessWidget {
  const _ParticipantVotingHint({required this.isVotingStarted});

  final bool isVotingStarted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AnimatedSwitcher(
      duration: AppMotion.medium,
      child: Text(
        isVotingStarted ? '投票が始まりました。' : 'ホストが投票を開始するまで待っています',
        key: ValueKey(isVotingStarted),
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isVotingStarted ? colors.primary : colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

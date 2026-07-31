import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/group_creation_draft.dart';
import '../services/room_repository.dart';
import '../services/user_error_messages.dart';
import '../theme/app_tokens.dart';
import '../widgets/group_code_badge.dart';
import '../widgets/primary_action_button.dart';
import 'create_group_page.dart';
import 'waiting_room_page.dart';

class GroupCreatedPage extends StatefulWidget {
  const GroupCreatedPage({super.key, required this.draft});

  static const routeName = '/group-created';

  final GroupCreationDraft draft;

  @override
  State<GroupCreatedPage> createState() => _GroupCreatedPageState();
}

class _GroupCreatedPageState extends State<GroupCreatedPage> {
  final RoomRepository _roomRepository = RoomRepositoryProvider.instance;

  String? _copyFeedback;
  bool _isExitAllowed = false;
  bool _isExitDialogOpen = false;
  bool _isDissolving = false;

  bool get _hasNoRestaurants =>
      widget.draft.restaurantSearchStatus == RestaurantSearchStatus.noResults;

  void _showCopySuccess(String message) {
    setState(() => _copyFeedback = message);
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted && _copyFeedback == message) {
        setState(() => _copyFeedback = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final horizontalPadding =
        MediaQuery.sizeOf(context).width < AppBreakpoints.compact
        ? AppSpacing.medium
        : AppSpacing.xLarge;

    return PopScope<void>(
      canPop: _isExitAllowed,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        unawaited(_confirmExit());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('招待'),
          actions: [GroupCodeBadge(code: widget.draft.groupId)],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    AppSpacing.xLarge,
                    horizontalPadding,
                    AppSpacing.xLarge,
                  ),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppSizes.contentMaxWidth,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _hasNoRestaurants
                                  ? const _WarningMark()
                                  : const _SuccessMark(),
                              const SizedBox(height: AppSpacing.medium),
                              Text(
                                _hasNoRestaurants ? '候補の店舗がありません' : '招待を送ろう',
                                style: theme.textTheme.headlineMedium,
                              ),
                              const SizedBox(height: AppSpacing.small),
                              Text(
                                _hasNoRestaurants
                                    ? '条件に合う店舗が見つからなかったため、このグループでは投票を始められません。'
                                    : 'ルームコードかURLを共有して、参加者を待ちます。',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xLarge),
                              if (_hasNoRestaurants)
                                const _NoRestaurantsNotice()
                              else ...[
                                _InvitationPanel(
                                  draft: widget.draft,
                                  onCopyUrl: () => _copyUrl(context),
                                  onCopyCode: () => _copyCode(context),
                                  onShare: () => _shareInvite(context),
                                ),
                                const SizedBox(height: AppSpacing.large),
                                AnimatedSwitcher(
                                  duration: AppMotion.medium,
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale: Tween<double>(
                                          begin: 0.96,
                                          end: 1,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _copyFeedback == null
                                      ? const SizedBox.shrink()
                                      : _CopySuccessBanner(
                                          key: ValueKey(_copyFeedback),
                                          message: _copyFeedback!,
                                        ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.xLarge),
                              _GroupSummary(draft: widget.draft),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    AppSpacing.small,
                    horizontalPadding,
                    AppSpacing.large,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSizes.actionMaxWidth,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: PrimaryActionButton(
                        label: _hasNoRestaurants ? '解散して作り直す' : '待機画面へ進む',
                        onPressed: _isDissolving
                            ? null
                            : _hasNoRestaurants
                            ? _dissolveAndReturnHome
                            : () {
                                Navigator.of(context).pushNamed(
                                  WaitingRoomPage.routeName,
                                  arguments: widget.draft,
                                );
                              },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmExit() async {
    if (_isExitDialogOpen || _isDissolving) {
      return;
    }
    _isExitDialogOpen = true;
    final shouldExit =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('グループを解散しますか？'),
            content: const Text(
              '解散すると招待URLとルームコードは使えなくなります。招待を続ける場合はこのまま進んでください。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('戻らない'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('解散して戻る'),
              ),
            ],
          ),
        ) ??
        false;
    _isExitDialogOpen = false;
    if (!mounted || !shouldExit) {
      return;
    }

    setState(() => _isDissolving = true);
    try {
      await _roomRepository.dissolveRoom(widget.draft);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isDissolving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(roomDissolveErrorMessage(error))),
        );
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() => _isExitAllowed = true);
    Navigator.of(context).pop();
  }

  Future<void> _dissolveAndReturnHome() async {
    if (_isDissolving) {
      return;
    }
    setState(() => _isDissolving = true);
    try {
      await _roomRepository.dissolveRoom(widget.draft);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isDissolving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(roomDissolveErrorMessage(error))),
        );
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() => _isExitAllowed = true);
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(CreateGroupPage.routeName, (route) => false);
  }

  Future<void> _copyUrl(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: widget.draft.inviteUrl));
    if (!context.mounted) {
      return;
    }
    _showCopySuccess('招待URLをコピーしました');
  }

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: widget.draft.groupId));
    if (!context.mounted) {
      return;
    }
    _showCopySuccess('グループコードをコピーしました');
  }

  Future<void> _shareInvite(BuildContext context) async {
    final text =
        'GuruMeetのルームに参加してください。\n'
        'コード: ${widget.draft.groupId}\n'
        '${widget.draft.inviteUrl}';
    try {
      await SharePlus.instance.share(
        ShareParams(title: 'GuruMeetの招待', subject: 'GuruMeetの招待', text: text),
      );
      if (!context.mounted) {
        return;
      }
      _showCopySuccess('招待を共有しました');
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: widget.draft.inviteUrl));
      if (!context.mounted) {
        return;
      }
      _showCopySuccess('共有できなかったためURLをコピーしました');
    }
  }
}

class _CopySuccessBanner extends StatelessWidget {
  const _CopySuccessBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.regular,
      ),
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
              message,
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
}

class _SuccessMark extends StatelessWidget {
  const _SuccessMark();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: AppSizes.successIndicator,
      height: AppSizes.successIndicator,
      decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
      child: Icon(
        Icons.check_rounded,
        color: colors.onPrimary,
        size: AppSizes.iconLarge,
      ),
    );
  }
}

class _WarningMark extends StatelessWidget {
  const _WarningMark();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: AppSizes.successIndicator,
      height: AppSizes.successIndicator,
      decoration: BoxDecoration(
        color: colors.errorContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.search_off_rounded,
        color: colors.onErrorContainer,
        size: AppSizes.iconLarge,
      ),
    );
  }
}

class _NoRestaurantsNotice extends StatelessWidget {
  const _NoRestaurantsNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.large),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_rounded, color: colors.onErrorContainer),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Text(
              '場所や予算の条件を変えると候補が見つかる可能性があります。参加者を招待する前に、このグループを解散して作り直してください。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvitationPanel extends StatelessWidget {
  const _InvitationPanel({
    required this.draft,
    required this.onCopyUrl,
    required this.onCopyCode,
    required this.onShare,
  });

  final GroupCreationDraft draft;
  final VoidCallback onCopyUrl;
  final VoidCallback onCopyCode;
  final VoidCallback onShare;

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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GROUP CODE  |  招待コード',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onPrimary.withValues(alpha: 0.72),
              letterSpacing: AppSizes.codeLabelLetterSpacing,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide =
                  constraints.maxWidth > AppBreakpoints.stackedActions;
              final codeBox = _CodeBox(draft: draft);
              final qrCode = _InviteQrCode(value: draft.inviteUrl);

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: codeBox),
                    const SizedBox(width: AppSpacing.medium),
                    qrCode,
                  ],
                );
              }

              return Column(
                children: [
                  codeBox,
                  const SizedBox(height: AppSpacing.medium),
                  Align(alignment: Alignment.centerLeft, child: qrCode),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.large),
          Text(
            '招待URL',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onPrimary.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: AppSpacing.micro),
          SelectableText(
            draft.inviteUrl,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.large),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: onCopyUrl,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.surface,
                    foregroundColor: colors.onSurface,
                  ),
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: AppSizes.iconMedium,
                  ),
                  label: const Text('リンクをコピー'),
                ),
              ),
              const SizedBox(width: AppSpacing.small),
              IconButton.filled(
                tooltip: 'グループコードをコピー',
                onPressed: onCopyCode,
                style: IconButton.styleFrom(
                  backgroundColor: colors.surface,
                  foregroundColor: colors.onSurface,
                ),
                icon: const Icon(Icons.numbers_rounded),
              ),
              const SizedBox(width: AppSpacing.small),
              IconButton(
                tooltip: '招待を共有',
                onPressed: onShare,
                color: colors.onPrimary,
                icon: const Icon(Icons.ios_share_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.draft});

  final GroupCreationDraft draft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.regular,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: SelectableText(
        draft.groupId,
        style: theme.textTheme.headlineSmall?.copyWith(
          color: colors.onSurface,
          letterSpacing: AppSizes.groupCodeLetterSpacing,
        ),
      ),
    );
  }
}

class _InviteQrCode extends StatelessWidget {
  const _InviteQrCode({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      label: '$value の招待QRコード',
      child: Container(
        width: AppSizes.qrCodeSize,
        height: AppSizes.qrCodeSize,
        padding: const EdgeInsets.all(AppSpacing.small),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: QrImageView(
          data: value,
          version: QrVersions.auto,
          gapless: false,
          padding: EdgeInsets.zero,
          backgroundColor: colors.surface,
          eyeStyle: QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: colors.onSurface,
          ),
          dataModuleStyle: QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: colors.onSurface,
          ),
        ),
      ),
    );
  }
}

class _GroupSummary extends StatelessWidget {
  const _GroupSummary({required this.draft});

  final GroupCreationDraft draft;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.large,
        vertical: AppSpacing.medium,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          _SummaryRow(label: '人数', value: '${draft.peopleCount}人'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.medium),
            child: Divider(),
          ),
          _SummaryRow(label: 'エリア', value: draft.area),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.medium),
            child: Divider(),
          ),
          _SummaryRow(label: '予算', value: draft.budget.label),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: AppSizes.summaryLabelWidth,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.medium),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

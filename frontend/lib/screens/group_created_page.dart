import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/group_creation_draft.dart';
import '../theme/app_tokens.dart';
import '../widgets/primary_action_button.dart';
import 'waiting_room_page.dart';

class GroupCreatedPage extends StatefulWidget {
  const GroupCreatedPage({super.key, required this.draft});

  static const routeName = '/group-created';

  final GroupCreationDraft draft;

  @override
  State<GroupCreatedPage> createState() => _GroupCreatedPageState();
}

class _GroupCreatedPageState extends State<GroupCreatedPage> {
  String? _copyFeedback;

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

    return Scaffold(
      appBar: AppBar(title: const Text('招待')),
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
                            const _SuccessMark(),
                            const SizedBox(height: AppSpacing.medium),
                            Text(
                              '招待を送ろう',
                              style: theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(height: AppSpacing.small),
                            Text(
                              'ルームコードかURLを共有して、参加者を待ちます。',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xLarge),
                            _InvitationPanel(
                              draft: widget.draft,
                              onCopyUrl: () => _copyUrl(context),
                              onCopyCode: () => _copyCode(context),
                              onShare: () => _showShareFeedback(context),
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
                      label: '待機画面へ進む',
                      onPressed: () {
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
    );
  }

  Future<void> _copyUrl(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: widget.draft.inviteUrl));
    if (!context.mounted) {
      return;
    }
    _showCopySuccess('招待URLをコピーしました');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('招待URLをコピーしました')));
  }

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: widget.draft.groupId));
    if (!context.mounted) {
      return;
    }
    _showCopySuccess('グループコードをコピーしました');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('グループコードをコピーしました')));
  }

  void _showShareFeedback(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('共有機能は現在準備中です。URLをコピーして共有できます。')),
    );
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
              final qrCode = _MockQrCode(value: draft.groupId);

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

class _MockQrCode extends StatelessWidget {
  const _MockQrCode({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      label: '$value のモックQRコード',
      child: Container(
        width: AppSizes.qrCodeSize,
        height: AppSizes.qrCodeSize,
        padding: const EdgeInsets.all(AppSpacing.small),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemCount: 49,
          itemBuilder: (context, index) {
            final seed = value.codeUnitAt(index % value.length);
            final isFilled =
                index < 8 ||
                index > 40 ||
                index % 7 == 0 ||
                (seed + index).isEven;
            return Padding(
              padding: const EdgeInsets.all(1.6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isFilled
                      ? colors.onSurface
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          },
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

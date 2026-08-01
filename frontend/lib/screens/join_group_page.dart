import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/group_creation_draft.dart';
import '../services/room_repository.dart';
import '../services/user_error_messages.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_shell.dart';
import '../widgets/primary_action_button.dart';
import 'match_page.dart';
import 'swipe_page.dart';
import 'waiting_room_page.dart';

class JoinGroupPage extends StatefulWidget {
  const JoinGroupPage({super.key, this.initialInviteToken});

  static const routeName = '/join-group';

  final String? initialInviteToken;

  @override
  State<JoinGroupPage> createState() => _JoinGroupPageState();
}

class _JoinGroupPageState extends State<JoinGroupPage> {
  final RoomRepository _roomRepository = RoomRepositoryProvider.instance;
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();

  bool _hasTriedSubmit = false;
  bool _isNavigating = false;
  bool _isLoadingPreview = false;
  RoomInvitePreview? _preview;
  String? _previewError;

  String? get _inviteToken {
    final token = widget.initialInviteToken?.trim();
    return token == null || token.isEmpty ? null : token;
  }

  bool get _hasValidLength => _codeController.text.trim().length == 5;
  bool get _hasInviteToken => _inviteToken != null;
  bool get _canPreviewInviteToken {
    final token = _inviteToken;
    return token != null &&
        RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(token);
  }

  bool get _canSubmitInvite =>
      !_canPreviewInviteToken ||
      (!_isLoadingPreview &&
          _previewError == null &&
          !(_preview?.isFull ?? false));

  @override
  void initState() {
    super.initState();
    final token = _inviteToken;
    if (token != null && RegExp(r'^[A-Za-z0-9]{5}$').hasMatch(token)) {
      _codeController.text = token.toUpperCase();
    }
    if (token != null && _canPreviewInviteToken) {
      _loadInvitePreview(token);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _joinGroup() async {
    if (_isNavigating) {
      return;
    }
    setState(() => _hasTriedSubmit = true);

    final isValid = _hasInviteToken || _formKey.currentState!.validate();
    if (!isValid) {
      _codeFocusNode.requestFocus();
      return;
    }

    setState(() => _isNavigating = true);
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final draft = await _roomRepository.joinRoom(
        code: _inviteToken ?? _codeController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      await _openJoinedRoom(draft);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(roomJoinErrorMessage(error))));
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }

  Future<void> _openJoinedRoom(GroupCreationDraft draft) async {
    switch (draft.phase) {
      case GroupPhase.waiting:
        await Navigator.of(
          context,
        ).pushReplacementNamed(WaitingRoomPage.routeName, arguments: draft);
      case GroupPhase.swiping:
        await Navigator.of(
          context,
        ).pushReplacementNamed(SwipePage.routeName, arguments: draft);
      case GroupPhase.result:
        final result = await _roomRepository.getResult(
          draft: draft,
          restaurants: const [],
          localChoices: const [],
        );
        if (!mounted) {
          return;
        }
        await Navigator.of(context).pushReplacementNamed(
          MatchPage.routeName,
          arguments: (draft: draft, result: result),
        );
    }
  }

  Future<void> _loadInvitePreview(String token) async {
    setState(() {
      _isLoadingPreview = true;
      _previewError = null;
    });
    try {
      final preview = await _roomRepository.getInvitePreview(
        inviteToken: token,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _preview = preview;
        _isLoadingPreview = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingPreview = false;
        _previewError = roomJoinErrorMessage(error);
      });
    }
  }

  String? _validateCode(String? value) {
    final code = value?.trim() ?? '';
    if (code.isEmpty) {
      return '招待コードを入力してください';
    }
    if (!RegExp(r'^[A-Z0-9]{5}$').hasMatch(code)) {
      return '5桁の英数字コードを入力してください';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AppShell(
      appBar: AppBar(title: const Text('グループに参加')),
      child: Form(
        key: _formKey,
        autovalidateMode: _hasTriedSubmit
            ? AutovalidateMode.always
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _hasInviteToken ? '招待リンクで\n参加する。' : '招待コードで\n参加する。',
              style: theme.textTheme.headlineLarge,
            ),
            const SizedBox(height: AppSpacing.regular),
            Text(
              _hasInviteToken
                  ? '共有されたリンクから対象のルームへ参加します。'
                  : '共有された5桁のコードを入力してください。',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            if (_hasInviteToken)
              _InviteTokenPanel(token: _inviteToken!)
            else
              TextFormField(
                controller: _codeController,
                focusNode: _codeFocusNode,
                autofocus: true,
                maxLength: 5,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  letterSpacing: AppSizes.groupCodeLetterSpacing,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '招待コード',
                ),
                inputFormatters: [
                  const _UppercaseTextFormatter(),
                  LengthLimitingTextInputFormatter(5),
                ],
                validator: _validateCode,
                onChanged: (_) => setState(() {}),
                onFieldSubmitted: (_) => _joinGroup(),
              ),
            const SizedBox(height: AppSpacing.medium),
            if (_canPreviewInviteToken) ...[
              _InvitePreviewPanel(
                isLoading: _isLoadingPreview,
                preview: _preview,
                errorMessage: _previewError,
                onRetry: () {
                  final token = _inviteToken;
                  if (token != null) {
                    _loadInvitePreview(token);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.medium),
            ],
            Text(
              _hasInviteToken
                  ? '参加できない場合は、招待リンクが正しいか確認してください。'
                  : '見つからない場合はコードを確認してください。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            SizedBox(
              width: double.infinity,
              child: PrimaryActionButton(
                label: '参加する',
                isLoading: _isNavigating,
                loadingLabel: '参加中',
                onPressed:
                    _isNavigating ||
                        (_hasInviteToken && !_canSubmitInvite) ||
                        (!_hasInviteToken && !_hasValidLength)
                    ? null
                    : _joinGroup,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvitePreviewPanel extends StatelessWidget {
  const _InvitePreviewPanel({
    required this.isLoading,
    required this.preview,
    required this.errorMessage,
    required this.onRetry,
  });

  final bool isLoading;
  final RoomInvitePreview? preview;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final preview = this.preview;

    if (isLoading) {
      return const LinearProgressIndicator();
    }

    if (errorMessage != null) {
      return _InlineNotice(
        icon: Icons.error_outline_rounded,
        message: errorMessage!,
        actionLabel: '再試行',
        onAction: onRetry,
      );
    }

    if (preview == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ルーム情報', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.small),
          Text('${preview.area} / ${preview.budget.label}'),
          const SizedBox(height: AppSpacing.micro),
          Text(
            '${preview.joinedCount} / ${preview.peopleCount}人が参加中',
            style: theme.textTheme.bodySmall?.copyWith(
              color: preview.isFull ? colors.error : colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (preview.isFull) ...[
            const SizedBox(height: AppSpacing.small),
            Text(
              'このルームは満員のため参加できません。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.onErrorContainer),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _InviteTokenPanel extends StatelessWidget {
  const _InviteTokenPanel({required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final visibleToken = token.length > 18
        ? '${token.substring(0, 8)}...${token.substring(token.length - 6)}'
        : token;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        children: [
          Icon(Icons.link_rounded, color: colors.primary),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Text(
              visibleToken,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UppercaseTextFormatter extends TextInputFormatter {
  const _UppercaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = newValue.text
        .replaceAll(RegExp('[^a-zA-Z0-9]'), '')
        .toUpperCase();
    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }
}

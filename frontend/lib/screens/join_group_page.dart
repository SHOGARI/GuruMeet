import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/room_repository.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_shell.dart';
import '../widgets/primary_action_button.dart';
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

  String? get _inviteToken {
    final token = widget.initialInviteToken?.trim();
    return token == null || token.isEmpty ? null : token;
  }

  bool get _hasValidLength => _codeController.text.trim().length == 5;
  bool get _hasInviteToken => _inviteToken != null;

  @override
  void initState() {
    super.initState();
    final token = _inviteToken;
    if (token != null && RegExp(r'^[A-Za-z0-9]{5}$').hasMatch(token)) {
      _codeController.text = token.toUpperCase();
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
      await Navigator.of(
        context,
      ).pushNamed(WaitingRoomPage.routeName, arguments: draft);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('ルームに参加できませんでした')));
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
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
                  hintText: 'G7M24',
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
                onPressed:
                    _isNavigating || (!_hasInviteToken && !_hasValidLength)
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

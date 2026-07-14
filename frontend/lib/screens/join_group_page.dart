import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/group_creation_draft.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_shell.dart';
import '../widgets/primary_action_button.dart';
import 'waiting_room_page.dart';

class JoinGroupPage extends StatefulWidget {
  const JoinGroupPage({super.key});

  static const routeName = '/join-group';

  @override
  State<JoinGroupPage> createState() => _JoinGroupPageState();
}

class _JoinGroupPageState extends State<JoinGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();

  bool _hasTriedSubmit = false;
  bool _isNavigating = false;

  bool get _hasValidLength => _codeController.text.trim().length == 4;

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

    final isValid = _formKey.currentState!.validate();
    if (!isValid) {
      _codeFocusNode.requestFocus();
      return;
    }

    setState(() => _isNavigating = true);
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(AppMotion.quick);
    if (!mounted) {
      return;
    }

    final draft = GroupCreationDraft.joinMock(
      groupId: _codeController.text.trim(),
    );
    await Navigator.of(
      context,
    ).pushNamed(WaitingRoomPage.routeName, arguments: draft);
    if (mounted) {
      setState(() => _isNavigating = false);
    }
  }

  String? _validateCode(String? value) {
    final code = value?.trim() ?? '';
    if (code.isEmpty) {
      return '招待コードを入力してください';
    }
    if (!RegExp(r'^[A-Z]{4}$').hasMatch(code)) {
      return '4文字の英字コードを入力してください';
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
            Text('招待コードで\n参加する。', style: theme.textTheme.headlineLarge),
            const SizedBox(height: AppSpacing.regular),
            Text(
              '共有された4文字のコードを入力してください。',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            TextFormField(
              controller: _codeController,
              focusNode: _codeFocusNode,
              autofocus: true,
              maxLength: 4,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                letterSpacing: AppSizes.groupCodeLetterSpacing,
              ),
              decoration: const InputDecoration(
                counterText: '',
                hintText: 'ABCD',
              ),
              inputFormatters: [
                const _UppercaseTextFormatter(),
                LengthLimitingTextInputFormatter(4),
              ],
              validator: _validateCode,
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) => _joinGroup(),
            ),
            const SizedBox(height: AppSpacing.medium),
            Text(
              'デモ版のため、入力したコードでモックのグループに参加します。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            SizedBox(
              width: double.infinity,
              child: PrimaryActionButton(
                label: '参加する',
                onPressed: _isNavigating || !_hasValidLength
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

class _UppercaseTextFormatter extends TextInputFormatter {
  const _UppercaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = newValue.text
        .replaceAll(RegExp('[^a-zA-Z]'), '')
        .toUpperCase();
    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }
}

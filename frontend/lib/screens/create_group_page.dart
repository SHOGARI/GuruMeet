import 'package:flutter/material.dart';

import '../models/group_creation_draft.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_shell.dart';
import '../widgets/primary_action_button.dart';
import 'group_created_page.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  static const routeName = '/create-group';

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _areaController = TextEditingController();
  final _areaFocusNode = FocusNode();

  int _peopleCount = 4;
  BudgetOption? _selectedBudget = BudgetOption.from2000To3000;
  bool _hasTriedSubmit = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _areaController.dispose();
    _areaFocusNode.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (_isSubmitting) {
      return;
    }
    setState(() {
      _hasTriedSubmit = true;
    });

    final isValid = _formKey.currentState!.validate();
    if (!isValid) {
      _areaFocusNode.requestFocus();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('エリアを入力するとグループを作成できます')));
      return;
    }

    if (_selectedBudget == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('予算を選んでください')));
      return;
    }

    setState(() => _isSubmitting = true);
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(AppMotion.quick);
    if (!mounted) {
      return;
    }

    final draft = GroupCreationDraft.createMock(
      peopleCount: _peopleCount,
      area: _areaController.text.trim(),
      budget: _selectedBudget!,
    );

    await Navigator.of(
      context,
    ).pushNamed(GroupCreatedPage.routeName, arguments: draft);
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AppShell(
      appBar: AppBar(title: const Text('グループ作成')),
      child: Form(
        key: _formKey,
        autovalidateMode: _hasTriedSubmit
            ? AutovalidateMode.always
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('今夜の集合を\nつくろう。', style: theme.textTheme.headlineLarge),
            const SizedBox(height: AppSpacing.regular),
            Text(
              '人数、場所、予算。決まったらすぐ招待できます。',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            _FormSection(
              step: '01',
              title: '何人で行く？',
              child: _PeopleCounter(
                peopleCount: _peopleCount,
                onDecrease: _peopleCount > 2
                    ? () => setState(() => _peopleCount--)
                    : null,
                onIncrease: _peopleCount < 10
                    ? () => setState(() => _peopleCount++)
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            _FormSection(
              step: '02',
              title: 'どのあたり？',
              child: TextFormField(
                controller: _areaController,
                focusNode: _areaFocusNode,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _createGroup(),
                decoration: const InputDecoration(hintText: '新宿、渋谷、池袋など'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '行きたいエリアを入力してください';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            _FormSection(
              step: '03',
              title: '予算はどれくらい？',
              child: Wrap(
                spacing: AppSpacing.small,
                runSpacing: AppSpacing.small,
                children: BudgetOption.values.map((budget) {
                  return ChoiceChip(
                    label: Text(budget.label),
                    selected: _selectedBudget == budget,
                    onSelected: (_) {
                      setState(() {
                        _selectedBudget = budget;
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            if (_hasTriedSubmit && _selectedBudget == null) ...[
              const SizedBox(height: AppSpacing.regular),
              Text(
                '希望の予算を選んでください',
                style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ],
            const SizedBox(height: AppSpacing.section),
            SizedBox(
              width: double.infinity,
              child: PrimaryActionButton(
                label: 'グループを作成',
                onPressed: _isSubmitting ? null : _createGroup,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.step,
    required this.title,
    required this.child,
  });

  final String step;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: AppSizes.touchTarget,
              height: AppSizes.touchTarget,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Text(
                step,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.regular),
            Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
          ],
        ),
        const SizedBox(height: AppSpacing.medium),
        child,
      ],
    );
  }
}

class _PeopleCounter extends StatelessWidget {
  const _PeopleCounter({
    required this.peopleCount,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int peopleCount;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.small),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: '人数を減らす',
            onPressed: onDecrease,
            icon: const Icon(Icons.remove_rounded),
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              label: '$peopleCount人',
              excludeSemantics: true,
              child: Text(
                '$peopleCount人',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
            ),
          ),
          IconButton.filled(
            tooltip: '人数を増やす',
            onPressed: onIncrease,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/group_creation_draft.dart';
import '../widgets/app_shell.dart';
import '../widgets/section_card.dart';
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

  int _peopleCount = 4;
  BudgetOption? _selectedBudget = BudgetOption.from2000To3000;
  bool _hasTriedSubmit = false;

  bool get _isFormReady =>
      _areaController.text.trim().isNotEmpty && _selectedBudget != null;

  @override
  void initState() {
    super.initState();
    _areaController.addListener(_handleFormChanged);
  }

  @override
  void dispose() {
    _areaController
      ..removeListener(_handleFormChanged)
      ..dispose();
    super.dispose();
  }

  void _handleFormChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _createGroup() {
    setState(() {
      _hasTriedSubmit = true;
    });

    if (!_formKey.currentState!.validate() || _selectedBudget == null) {
      return;
    }

    final draft = GroupCreationDraft(
      peopleCount: _peopleCount,
      area: _areaController.text.trim(),
      budget: _selectedBudget!,
    );

    Navigator.of(
      context,
    ).pushNamed(GroupCreatedPage.routeName, arguments: draft);
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      appBar: AppBar(title: const Text('グループ作成')),
      bottomBar: FilledButton(
        onPressed: _isFormReady ? _createGroup : null,
        child: const Text('グループを作成'),
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: _hasTriedSubmit
            ? AutovalidateMode.always
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '食事メンバーの条件を決めて、招待URLを発行します。',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('人数', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(
                    '2人以上、最大10人まで設定できます。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: _peopleCount > 2
                            ? () => setState(() => _peopleCount--)
                            : null,
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$_peopleCount人',
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineMedium?.copyWith(fontSize: 28),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton.filled(
                        onPressed: _peopleCount < 10
                            ? () => setState(() => _peopleCount++)
                            : null,
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('エリア', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _areaController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(hintText: '例: 新宿、渋谷、池袋'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'エリアを入力してください。';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('予算', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
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
                  if (_hasTriedSubmit && _selectedBudget == null) ...[
                    const SizedBox(height: 12),
                    Text(
                      '予算を選択してください。',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

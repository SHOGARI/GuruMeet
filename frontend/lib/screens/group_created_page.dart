import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/group_creation_draft.dart';
import '../widgets/app_shell.dart';
import '../widgets/section_card.dart';
import 'home_page.dart';

class GroupCreatedPage extends StatelessWidget {
  const GroupCreatedPage({super.key, required this.draft});

  static const routeName = '/group-created';

  final GroupCreationDraft draft;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      appBar: AppBar(title: const Text('作成完了')),
      bottomBar: FilledButton(
        onPressed: () {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(HomePage.routeName, (route) => false);
        },
        child: const Text('次へ進む'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'グループを作成しました',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            'このURLを参加者に共有すると、同じ条件で参加できます。',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryRow(label: '人数', value: '${draft.peopleCount}人'),
                const Divider(height: 28),
                _SummaryRow(label: 'エリア', value: draft.area),
                const Divider(height: 28),
                _SummaryRow(label: '予算', value: draft.budget.label),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('招待URL', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SelectableText(
                    draft.inviteUrl,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () => _copyUrl(context),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('URLをコピーする'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _showShareMock(context),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('URLを共有する'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyUrl(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: draft.inviteUrl));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('招待URLをコピーしました。')));
  }

  void _showShareMock(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('共有機能はバックエンド接続時に実装予定です。')));
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

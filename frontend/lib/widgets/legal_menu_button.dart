import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../generated/legal_documents.g.dart';
import '../theme/app_tokens.dart';

class LegalMenuButton extends StatelessWidget {
  const LegalMenuButton({super.key});

  static const _documents = <_LegalDocument>[
    _LegalDocument('privacy-policy', 'プライバシーポリシー'),
    _LegalDocument('terms-of-service', '利用規約'),
    _LegalDocument('contact', 'お問い合わせ'),
    _LegalDocument('licenses', 'ライセンス'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final availableWidth =
        MediaQuery.sizeOf(context).width - (AppSpacing.medium * 2);

    return SizedBox(
      width: availableWidth,
      height: AppSizes.touchTarget,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '© 2026 GuruMeet',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FloatingActionButton.small(
              tooltip: '法務・お問い合わせ',
              onPressed: () => _openMenu(context),
              child: const Icon(Icons.menu_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMenu(BuildContext context) async {
    final selected = await showModalBottomSheet<_LegalDocument>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.large),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xLarge,
                  0,
                  AppSpacing.xLarge,
                  AppSpacing.small,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('メニュー', style: theme.textTheme.titleLarge),
                ),
              ),
              for (final document in _documents)
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(document.title),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(sheetContext).pop(document),
                ),
            ],
          ),
        );
      },
    );

    if (selected != null && context.mounted) {
      await _showDocument(context, selected);
    }
  }

  Future<void> _showDocument(BuildContext context, _LegalDocument document) {
    final markdown = legalDocumentMarkdown[document.key];
    assert(
      markdown != null,
      'Missing generated legal document: ${document.key}',
    );

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _LegalDocumentSheet(
        document: document,
        markdown: markdown ?? '# ${document.title}\n\n内容を読み込めませんでした。',
      ),
    );
  }
}

class _LegalDocumentSheet extends StatelessWidget {
  const _LegalDocumentSheet({required this.document, required this.markdown});

  final _LegalDocument document;
  final String markdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.sizeOf(context);

    return SizedBox(
      height: screenSize.height * 0.9,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xLarge,
              0,
              AppSpacing.small,
              AppSpacing.small,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    document.title,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: '閉じる',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xLarge,
                AppSpacing.large,
                AppSpacing.xLarge,
                AppSpacing.xxLarge,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._buildMarkdown(context),
                      if (document.key == 'licenses') ...[
                        const SizedBox(height: AppSpacing.xLarge),
                        OutlinedButton.icon(
                          onPressed: () => showLicensePage(
                            context: context,
                            applicationName: 'GuruMeet',
                            applicationVersion: '1.0.0',
                          ),
                          icon: const Icon(Icons.description_outlined),
                          label: const Text('オープンソースライセンスを表示'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMarkdown(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final widgets = <Widget>[];
    final lines = markdown.split('\n');

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trim();
      if (line.isEmpty || (index == 0 && line.startsWith('# '))) {
        continue;
      }
      if (line.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.xLarge,
              bottom: AppSpacing.small,
            ),
            child: Text(
              line.substring(3),
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
        );
      } else if (line.startsWith('- ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.small),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: SelectableText(line.substring(2))),
              ],
            ),
          ),
        );
      } else if (_isWebUrl(line)) {
        widgets.add(
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _openUrl(context, line),
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(line),
            ),
          ),
        );
      } else if (_isEmail(line)) {
        widgets.add(
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _openUrl(context, 'mailto:$line'),
              icon: const Icon(Icons.email_outlined),
              label: Text(line),
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.regular),
            child: SelectableText(line, style: theme.textTheme.bodyMedium),
          ),
        );
      }
    }
    return widgets;
  }

  bool _isWebUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
  }

  bool _isEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  Future<void> _openUrl(BuildContext context, String value) async {
    final opened = await launchUrl(
      Uri.parse(value),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('リンクを開けませんでした')));
    }
  }
}

class _LegalDocument {
  const _LegalDocument(this.key, this.title);

  final String key;
  final String title;
}

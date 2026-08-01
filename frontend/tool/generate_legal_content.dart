import 'dart:convert';
import 'dart:io';

const _documents = <String, String>{
  'privacy-policy': '../docs/legal/privacy-policy.md',
  'terms-of-service': '../docs/legal/terms-of-service.md',
  'contact': '../docs/legal/contact.md',
  'licenses': '../docs/legal/licenses.md',
};

const _outputPath = 'lib/generated/legal_documents.g.dart';

void main() {
  final output = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('// Source: ../docs/legal/*.md')
    ..writeln()
    ..writeln('const legalDocumentMarkdown = <String, String>{');

  for (final entry in _documents.entries) {
    final source = File(entry.value);
    if (!source.existsSync()) {
      stderr.writeln('Missing legal document: ${source.path}');
      exitCode = 1;
      return;
    }

    final markdown = source.readAsStringSync().replaceAll('\r\n', '\n');
    if (!markdown.startsWith('# ')) {
      stderr.writeln(
        'Legal document must start with a level-1 heading: ${source.path}',
      );
      exitCode = 1;
      return;
    }
    output
      ..writeln('  ${jsonEncode(entry.key)}:')
      ..writeln('      ${jsonEncode(markdown)},');
  }

  output.writeln('};');
  final target = File(_outputPath);
  target.parent.createSync(recursive: true);
  target.writeAsStringSync(output.toString());
  stdout.writeln('Generated ${target.path} from docs/legal.');
}

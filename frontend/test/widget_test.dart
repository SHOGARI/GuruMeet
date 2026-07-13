import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gurumeet/app.dart';

void main() {
  testWidgets('home to create group flow renders', (tester) async {
    await tester.pumpWidget(const GuruMeetApp());

    expect(find.text('GuruMeet'), findsOneWidget);
    expect(find.text('グループを作る'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'グループを作る'));
    await tester.pumpAndSettle();

    expect(find.text('グループ作成'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '渋谷');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'グループを作成'));
    await tester.pumpAndSettle();

    expect(find.text('グループを作成しました'), findsOneWidget);
    expect(find.text('渋谷'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gurumeet/app.dart';
import 'package:gurumeet/models/group_creation_draft.dart';

void main() {
  test('mock group code uses four uppercase letters', () {
    final draft = GroupCreationDraft.createMock(
      peopleCount: 4,
      area: '渋谷',
      budget: BudgetOption.from2000To3000,
    );

    expect(draft.groupId, matches(RegExp(r'^[A-Z]{4}$')));
    expect(draft.inviteUrl, 'https://gurumeet.app/join/${draft.groupId}');
  });

  testWidgets('home to create group flow renders', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);

    await tester.pumpWidget(const GuruMeetApp());

    expect(find.text('GuruMeet'), findsOneWidget);
    expect(find.text('グループを作る'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'グループを作る'));
    await tester.pumpAndSettle();

    expect(find.text('グループ作成'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'グループを作成'))
          .onPressed,
      isNotNull,
    );

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'グループを作成'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'グループを作成'));
    await tester.pump();

    expect(find.text('行きたいエリアを入力してください'), findsOneWidget);
    expect(find.text('エリアを入力するとグループを作成できます'), findsOneWidget);

    await tester.tap(find.byTooltip('人数を増やす'));
    await tester.pump();
    expect(find.text('5人'), findsOneWidget);

    await tester.tap(find.byTooltip('人数を減らす'));
    await tester.pump();
    expect(find.text('4人'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '渋谷');
    await tester.pump();

    await tester.ensureVisible(find.widgetWithText(ChoiceChip, '3,000〜5,000円'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '3,000〜5,000円'));
    await tester.pump();

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'グループを作成'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'グループを作成'));
    await tester.pumpAndSettle();

    expect(find.text('招待'), findsOneWidget);
    expect(find.text('グループを作成しました。\n招待を送ろう。'), findsOneWidget);
    expect(find.text('GROUP CODE  |  招待コード'), findsOneWidget);
    expect(find.text('渋谷'), findsOneWidget);
    expect(find.text('3,000〜5,000円'), findsOneWidget);
    expect(find.textContaining('https://gurumeet.app/join/'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('グループを作成しました。\n招待を送ろう。')).dy,
      greaterThan(0),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'メンバーを待つ'));
    await tester.pumpAndSettle();

    expect(find.text('メンバー待機'), findsOneWidget);
    expect(find.text('1 / 4人'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, '全員がそろうと開始できます'),
          )
          .onPressed,
      isNull,
    );

    for (var index = 0; index < 3; index++) {
      final joinButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '招待URLから参加（デモ）'),
      );
      joinButton.onPressed!();
      await tester.pumpAndSettle();
    }

    expect(find.text('4 / 4人'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'お店選びを始める'));
    await tester.pumpAndSettle();

    expect(find.text('食べたい？'), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);

    for (var participant = 0; participant < 4; participant++) {
      for (var restaurant = 0; restaurant < 5; restaurant++) {
        final likesRestaurant = participant == 0 && restaurant == 0;
        await tester.tap(
          find.widgetWithText(
            likesRestaurant ? FilledButton : OutlinedButton,
            likesRestaurant ? '食べたい' : 'パス',
          ),
        );
        await tester.pumpAndSettle();
      }
    }

    expect(find.text('今日のお店は\nここに決まり。'), findsOneWidget);
    expect(find.text('GINZA SORA'), findsOneWidget);
    expect(find.text('店舗詳細を見る'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '店舗詳細を見る'));
    await tester.pumpAndSettle();

    expect(find.text('店舗詳細'), findsOneWidget);
    expect(find.text('Google Mapsで見る'), findsOneWidget);
    expect(find.text('ホームへ戻る'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'ホームへ戻る'));
    await tester.pumpAndSettle();

    expect(find.text('GuruMeet'), findsOneWidget);
  });

  testWidgets('home supports compact and web widths', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1;

    for (final size in [const Size(320, 568), const Size(1440, 900)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(const GuruMeetApp());
      await tester.pump();

      expect(find.text('今日、どこ食べに行く？'), findsOneWidget);
      expect(find.text('グループを作る'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gurumeet/app.dart';
import 'package:gurumeet/models/group_creation_draft.dart';
import 'package:gurumeet/models/restaurant_preview.dart';
import 'package:gurumeet/screens/group_created_page.dart';
import 'package:gurumeet/screens/match_page.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  test('mock group code uses five uppercase alphanumeric characters', () {
    final draft = GroupCreationDraft.createMock(
      peopleCount: 4,
      area: '渋谷',
      budget: BudgetOption.from2000To3000,
    );

    expect(draft.groupId, matches(RegExp(r'^[A-Z0-9]{5}$')));
    expect(draft.groupId, 'G7M24');
    expect(draft.inviteUrl, 'https://gurumeet.app/#/join/${draft.groupId}');
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

    tester
        .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add_rounded))
        .onPressed!();
    await tester.pump();
    expect(find.text('5人'), findsOneWidget);

    tester
        .widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.remove_rounded),
        )
        .onPressed!();
    await tester.pump();
    expect(find.text('4人'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '渋谷');
    await tester.pump();

    await tester.ensureVisible(find.widgetWithText(ChoiceChip, '3,000〜5,000円'));
    await tester.pumpAndSettle();
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '3,000〜5,000円'))
        .onSelected!(true);
    await tester.pump();

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'グループを作成'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'グループを作成'));
    await tester.pumpAndSettle();

    expect(find.text('招待'), findsOneWidget);
    expect(find.text('招待を送ろう'), findsOneWidget);
    expect(find.text('GROUP CODE  |  招待コード'), findsOneWidget);
    expect(find.text('渋谷'), findsOneWidget);
    expect(find.text('3,000〜5,000円'), findsOneWidget);
    expect(find.textContaining('https://gurumeet.app/#/join/'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(tester.getTopLeft(find.text('招待を送ろう')).dy, greaterThan(0));

    await tester.tap(find.widgetWithText(FilledButton, '待機画面へ進む'));
    await tester.pumpAndSettle();

    expect(find.text('メンバー待機'), findsOneWidget);
    expect(find.text('WAITING'), findsOneWidget);
    expect(find.text('参加メンバー'), findsOneWidget);
    expect(find.text('ルームコード'), findsOneWidget);
    expect(find.text('コピー'), findsOneWidget);
    expect(find.text('ホスト'), findsOneWidget);
    expect(find.text('準備OK'), findsOneWidget);
    expect(find.text('1 / 4人'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '投票を開始'))
          .onPressed,
      isNull,
    );

    await tester.pump(const Duration(milliseconds: 5200));
    await tester.pumpAndSettle();

    expect(find.text('4 / 4人'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '投票を開始'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.widgetWithText(FilledButton, '投票を開始'));
    await tester.pumpAndSettle();

    expect(find.text('食べたい？'), findsOneWidget);
    expect(find.text('残り 5 / 5'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'ひとつ戻す'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'ひとつ戻す'))
          .onPressed,
      isNull,
    );

    for (var restaurant = 0; restaurant < 5; restaurant++) {
      final likesRestaurant = restaurant == 0;
      await tester.tap(
        find.widgetWithIcon(
          IconButton,
          likesRestaurant ? Icons.favorite_rounded : Icons.close_rounded,
        ),
      );
      await tester.pumpAndSettle();
      if (restaurant == 0) {
        expect(find.text('残り 4 / 5'), findsOneWidget);
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'ひとつ戻す'),
              )
              .onPressed,
          isNotNull,
        );
        await tester.tap(find.widgetWithText(OutlinedButton, 'ひとつ戻す'));
        await tester.pumpAndSettle();
        expect(find.text('残り 5 / 5'), findsOneWidget);
        await tester.tap(
          find.widgetWithIcon(IconButton, Icons.favorite_rounded),
        );
        await tester.pumpAndSettle();
      }
    }

    expect(find.text('投票完了'), findsOneWidget);
    expect(find.text('みんなの投票を待っています'), findsOneWidget);
    expect(find.text('1 / 4人 完了'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 4600));
    await tester.pumpAndSettle();
    expect(find.text('4 / 4人 完了'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(FilledButton, '結果を見る'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '結果を見る'));
    await tester.pumpAndSettle();

    expect(find.text('今日のお店が決定。'), findsOneWidget);
    expect(find.text('GINZA SORA'), findsAtLeastNWidgets(1));
    expect(find.text('全員一致'), findsAtLeastNWidgets(1));
    expect(find.text('ランキング'), findsOneWidget);
    expect(find.text('Googleマップで開く'), findsOneWidget);
    expect(find.text('この店に決定'), findsAtLeastNWidgets(1));
    expect(find.text('もう一度選ぶ'), findsOneWidget);
    expect(find.text('店舗詳細を見る'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, '店舗詳細を見る'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '店舗詳細を見る'));
    await tester.pumpAndSettle();

    expect(find.text('店舗詳細'), findsOneWidget);
    expect(find.text('Google Mapsで見る'), findsOneWidget);
    expect(find.text('ホームへ戻る'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'ホームへ戻る'));
    await tester.pumpAndSettle();

    expect(find.text('GuruMeet'), findsOneWidget);
  });

  testWidgets('invite link route renders join screen', (tester) async {
    await tester.pumpWidget(const GuruMeetApp());
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed('/join/123e4567-e89b-12d3-a456-426614174000');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('グループに参加'), findsOneWidget);
    expect(find.text('招待リンクで\n参加する。'), findsOneWidget);
    expect(find.text('123e4567...174000'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '参加する'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('legacy code invite route can still join', (tester) async {
    await tester.pumpWidget(const GuruMeetApp());
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed('/join/AB12C');
    await tester.pumpAndSettle();

    expect(find.text('グループに参加'), findsOneWidget);
    expect(find.text('AB12C'), findsOneWidget);
    expect(find.text('ルーム情報'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '参加する'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('unknown route shows not found fallback', (tester) async {
    await tester.pumpWidget(const GuruMeetApp());
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed('/missing-page');
    await tester.pumpAndSettle();

    expect(find.text('ページが見つかりません'), findsOneWidget);
    expect(find.text('404'), findsOneWidget);
    expect(find.text('/missing-page'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'ホームへ戻る'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'コードで参加する'), findsOneWidget);
  });

  testWidgets('invalid direct route arguments show not found fallback', (
    tester,
  ) async {
    await tester.pumpWidget(const GuruMeetApp());
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(GroupCreatedPage.routeName);
    await tester.pumpAndSettle();

    expect(find.text('ページが見つかりません'), findsOneWidget);
    expect(find.text(GroupCreatedPage.routeName), findsOneWidget);
  });

  testWidgets('tie result shows tie notice and restart action', (tester) async {
    final draft = GroupCreationDraft.createMock(
      peopleCount: 3,
      area: '渋谷',
      budget: BudgetOption.from2000To3000,
    );
    final result = RestaurantMatchResult(
      restaurant: mockRestaurants.first,
      peopleCount: 3,
      results: [
        RestaurantVoteResult(
          restaurant: mockRestaurants[0],
          likeCount: 2,
          rejectCount: 1,
        ),
        RestaurantVoteResult(
          restaurant: mockRestaurants[1],
          likeCount: 2,
          rejectCount: 1,
        ),
        RestaurantVoteResult(
          restaurant: mockRestaurants[2],
          likeCount: 1,
          rejectCount: 2,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MatchPage(draft: draft, result: result),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('同率1位。候補から選べます。'), findsOneWidget);
    expect(find.text('選び直す'), findsOneWidget);
    expect(find.text('決選投票をする'), findsNothing);
  });

  testWidgets('api room result hides restart action', (tester) async {
    const draft = GroupCreationDraft(
      peopleCount: 3,
      area: '渋谷',
      budget: BudgetOption.from2000To3000,
      groupId: 'AB12C',
      isHost: true,
      roomId: '123e4567-e89b-12d3-a456-426614174000',
    );
    final result = RestaurantMatchResult(
      restaurant: mockRestaurants.first,
      peopleCount: 3,
      results: [
        RestaurantVoteResult(
          restaurant: mockRestaurants[0],
          likeCount: 2,
          rejectCount: 1,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MatchPage(draft: draft, result: result),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('もう一度選ぶ'), findsNothing);
  });

  testWidgets('create group always shows condition inputs', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);

    await tester.pumpWidget(const GuruMeetApp());

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'グループを作る'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'グループを作る'));
    await tester.pumpAndSettle();

    expect(find.text('何人で行く？'), findsOneWidget);
    expect(find.text('どのあたり？'), findsOneWidget);
    expect(find.text('予算はどれくらい？'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '現在地から入力'), findsOneWidget);
    expect(find.text('4人'), findsOneWidget);

    for (final budget in BudgetOption.values) {
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, budget.label));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, budget.label), findsOneWidget);
    }

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'グループを作成'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'グループを作成'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home to join group flow renders', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);

    await tester.pumpWidget(const GuruMeetApp());

    await tester.tap(find.widgetWithText(OutlinedButton, 'コードで参加する'));
    await tester.pumpAndSettle();

    expect(find.text('グループに参加'), findsOneWidget);
    expect(find.text('招待コードで\n参加する。'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '参加する'))
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextFormField), 'ab12cd');
    await tester.pump();
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller?.text,
      'AB12C',
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '参加する'))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.widgetWithText(FilledButton, '参加する'));
    await tester.pumpAndSettle();

    expect(find.text('メンバー待機'), findsOneWidget);
    expect(find.text('1 / 4人'), findsOneWidget);
    expect(
      find.textContaining('https://gurumeet.app/#/join/AB12C'),
      findsOneWidget,
    );
  });

  testWidgets('home supports compact and web widths', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1;

    for (final size in [
      const Size(375, 812),
      const Size(390, 844),
      const Size(430, 932),
      const Size(768, 1024),
      const Size(1440, 900),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(const GuruMeetApp());
      await tester.pump();

      expect(find.text('今日どこ行く？'), findsOneWidget);
      expect(find.text('グループを作る'), findsOneWidget);
      expect(find.text('コードで参加する'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

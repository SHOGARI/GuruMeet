import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gurumeet/app.dart';
import 'package:gurumeet/models/group_creation_draft.dart';
import 'package:gurumeet/models/restaurant_preview.dart';
import 'package:gurumeet/screens/group_created_page.dart';
import 'package:gurumeet/screens/match_page.dart';
import 'package:gurumeet/widgets/restaurant_image.dart';
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
    expect(draft.inviteUrl, 'http://localhost:3000/#/join/${draft.groupId}');
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
    expect(find.widgetWithText(OutlinedButton, '現在地から入力'), findsOneWidget);
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

    expect(find.text('都道府県を選択してください'), findsOneWidget);
    expect(find.text('先に都道府県を選択してください'), findsOneWidget);
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

    await tester.tap(find.byKey(const ValueKey('prefecture-select-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('東京都').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'グループを作成'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('prefecture-select-field')),
    );
    await tester.pumpAndSettle();
    expect(find.text('東京都'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('location-search-field')),
      '渋谷',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('渋谷駅'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('location-search-field')));
    await tester.pump();
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('location-search-field')),
          )
          .controller
          ?.text,
      '渋谷駅・東京都渋谷区',
    );
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

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

    // 招待完了画面を挟まず、招待情報を含む待機画面へ直接進む。
    expect(find.text('メンバー待機'), findsOneWidget);
    expect(find.text('WAITING'), findsOneWidget);
    expect(
      find.textContaining('http://localhost:3000/#/join/'),
      findsOneWidget,
    );
    expect(find.byType(QrImageView), findsOneWidget);

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

    final blockedPop = tester
        .state<NavigatorState>(find.byType(Navigator))
        .maybePop();
    await tester.pumpAndSettle();
    expect(find.text('グループを解散しますか？'), findsOneWidget);
    expect(find.text('解散して戻る'), findsOneWidget);
    await tester.tap(find.text('待機を続ける'));
    await tester.pumpAndSettle();
    expect(await blockedPop, isTrue);
    expect(find.text('メンバー待機'), findsOneWidget);

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

    expect(find.text('このお店、行きたい？'), findsOneWidget);
    expect(find.text('残り 5 / 5'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator).first,
          )
          .value,
      0,
    );
    expect(find.widgetWithText(OutlinedButton, 'ひとつ戻す'), findsOneWidget);
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).automaticallyImplyLeading,
      isFalse,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'ひとつ戻す'))
          .onPressed,
      isNull,
    );

    await tester.drag(find.text('GINZA SORA').first, const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(find.text('残り 5 / 5'), findsOneWidget);

    for (var restaurant = 0; restaurant < 5; restaurant++) {
      final likesRestaurant = restaurant == 0;
      await tester.tap(
        find.widgetWithIcon(
          IconButton,
          likesRestaurant
              ? Icons.bookmark_add_rounded
              : Icons.remove_circle_outline_rounded,
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
          find.widgetWithIcon(IconButton, Icons.bookmark_add_rounded),
        );
        await tester.pumpAndSettle();
      }
    }

    expect(find.text('これで全部完了しますか？'), findsOneWidget);
    expect(find.text('投票を完了する'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'ひとつ戻す'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, '投票を完了する'));
    await tester.pumpAndSettle();

    expect(find.text('投票完了'), findsOneWidget);
    expect(find.text('みんなの投票を待っています'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'ひとつ戻す'), findsNothing);
    expect(find.text('1 / 4人 完了'), findsOneWidget);
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).automaticallyImplyLeading,
      isFalse,
    );
    await tester.pump(const Duration(milliseconds: 4600));
    await tester.pumpAndSettle();
    expect(find.text('4 / 4人 完了'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(FilledButton, '結果を見る'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '結果を見る'));
    await tester.pumpAndSettle();

    expect(find.text('今日のお店が決定。'), findsOneWidget);
    expect(find.text('RESULT'), findsOneWidget);
    expect(find.text('支持率'), findsOneWidget);
    expect(find.text('GINZA SORA'), findsAtLeastNWidgets(1));
    expect(find.text('全員一致'), findsAtLeastNWidgets(1));
    expect(find.text('ランキング'), findsOneWidget);
    expect(find.text('Googleマップで開く'), findsOneWidget);
    expect(find.text('この店に決定'), findsAtLeastNWidgets(1));
    expect(find.text('もう一度選ぶ'), findsOneWidget);
    expect(find.text('店舗詳細を見る'), findsOneWidget);
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).automaticallyImplyLeading,
      isFalse,
    );

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, '店舗詳細を見る'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '店舗詳細を見る'));
    await tester.pumpAndSettle();

    expect(find.text('店舗詳細'), findsOneWidget);
    expect(find.text('Googleマップで開く'), findsOneWidget);
    expect(find.text('ホームへ戻る'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'ホームへ戻る'));
    await tester.pumpAndSettle();

    expect(find.text('GuruMeet'), findsOneWidget);
  });

  testWidgets('group created prompts dissolve when restaurants are empty', (
    tester,
  ) async {
    final draft = GroupCreationDraft.fromApi(
      roomId: '00000000-0000-0000-0000-000000000001',
      groupId: 'A7K2F',
      peopleCount: 4,
      area: '北千住駅・東京都足立区',
      budget: BudgetOption.from2000To3000,
      isHost: true,
      restaurantSearchStatus: RestaurantSearchStatus.noResults,
    );

    await tester.pumpWidget(MaterialApp(home: GroupCreatedPage(draft: draft)));

    expect(find.text('候補の店舗がありません'), findsOneWidget);
    expect(find.textContaining('このグループでは投票を始められません'), findsOneWidget);
    expect(find.textContaining('このグループを解散して作り直してください'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '解散して作り直す'), findsOneWidget);
    expect(find.text('GROUP CODE  |  招待コード'), findsNothing);
    expect(find.text('招待URL'), findsNothing);
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

  testWidgets('host can choose tied winner before final decision', (
    tester,
  ) async {
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

    expect(find.text('同率1位。候補を選択。'), findsOneWidget);
    expect(find.text('話し合って、ホストが決定してください。'), findsOneWidget);
    expect(find.text('選び直す'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'この店に決定'), findsOneWidget);
    expect(find.text('決選投票をする'), findsNothing);

    final secondRankedResult = find.byKey(
      ValueKey('ranked-result-${mockRestaurants[1].id}'),
    );
    await tester.ensureVisible(secondRankedResult);
    await tester.pumpAndSettle();
    await tester.tap(secondRankedResult);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<RestaurantImage>(
            find.byKey(ValueKey('winner-image-${mockRestaurants[1].id}')),
          )
          .imageUrl,
      mockRestaurants[1].imageUrl,
    );

    final confirmButton = find.widgetWithText(FilledButton, 'この店に決定');
    await tester.ensureVisible(confirmButton);
    await tester.pumpAndSettle();
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(find.text('今日のお店が決定。'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'この店に決定'), findsNothing);
  });

  testWidgets('non-host cannot choose tied winner', (tester) async {
    const draft = GroupCreationDraft(
      peopleCount: 3,
      area: '渋谷',
      budget: BudgetOption.from2000To3000,
      groupId: 'AB12C',
      isHost: false,
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
        RestaurantVoteResult(
          restaurant: mockRestaurants[1],
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

    expect(find.text('同率1位。候補を選択。'), findsOneWidget);
    expect(find.text('話し合って、ホストが決定してください。'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'この店に決定'), findsNothing);
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
    expect(find.byType(TextFormField), findsNWidgets(2));
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, '現在地から入力'));
    await tester.pumpAndSettle();
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
      find.textContaining('http://localhost:3000/#/join/AB12C'),
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

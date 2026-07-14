import 'package:flutter/material.dart';

import 'models/group_creation_draft.dart';
import 'models/restaurant_preview.dart';
import 'screens/create_group_page.dart';
import 'screens/group_created_page.dart';
import 'screens/home_page.dart';
import 'screens/match_page.dart';
import 'screens/restaurant_detail_page.dart';
import 'screens/swipe_page.dart';
import 'screens/waiting_room_page.dart';
import 'theme/app_theme.dart';
import 'theme/app_tokens.dart';

class GuruMeetApp extends StatelessWidget {
  const GuruMeetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GuruMeet',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      initialRoute: HomePage.routeName,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case HomePage.routeName:
            return MaterialPageRoute<void>(
              builder: (_) => const HomePage(),
              settings: settings,
            );
          case CreateGroupPage.routeName:
            return MaterialPageRoute<void>(
              builder: (_) => const CreateGroupPage(),
              settings: settings,
            );
          case GroupCreatedPage.routeName:
            final draft = settings.arguments;
            if (draft case final GroupCreationDraft value) {
              return MaterialPageRoute<void>(
                builder: (_) => GroupCreatedPage(draft: value),
                settings: settings,
              );
            }
            return _errorRoute();
          case WaitingRoomPage.routeName:
            final draft = settings.arguments;
            if (draft case final GroupCreationDraft value) {
              return MaterialPageRoute<void>(
                builder: (_) => WaitingRoomPage(draft: value),
                settings: settings,
              );
            }
            return _errorRoute();
          case SwipePage.routeName:
            final draft = settings.arguments;
            if (draft case final GroupCreationDraft value) {
              return MaterialPageRoute<void>(
                builder: (_) => SwipePage(draft: value),
                settings: settings,
              );
            }
            return _errorRoute();
          case MatchPage.routeName:
            final arguments = settings.arguments;
            if (arguments case (
              draft: final GroupCreationDraft draft,
              restaurant: final RestaurantPreview restaurant,
            )) {
              return MaterialPageRoute<void>(
                builder: (_) => MatchPage(draft: draft, restaurant: restaurant),
                settings: settings,
              );
            }
            return _errorRoute();
          case RestaurantDetailPage.routeName:
            final arguments = settings.arguments;
            if (arguments case (
              draft: final GroupCreationDraft draft,
              restaurant: final RestaurantPreview restaurant,
            )) {
              return MaterialPageRoute<void>(
                builder: (_) =>
                    RestaurantDetailPage(draft: draft, restaurant: restaurant),
                settings: settings,
              );
            }
            return _errorRoute();
          default:
            return _errorRoute();
        }
      },
    );
  }

  MaterialPageRoute<void> _errorRoute() {
    return MaterialPageRoute<void>(
      builder: (_) => const Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xLarge),
              child: Text('ページの読み込みに失敗しました。'),
            ),
          ),
        ),
      ),
    );
  }
}

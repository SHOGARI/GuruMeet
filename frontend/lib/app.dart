import 'package:flutter/material.dart';

import 'models/group_creation_draft.dart';
import 'screens/create_group_page.dart';
import 'screens/group_created_page.dart';
import 'screens/home_page.dart';
import 'theme/app_theme.dart';

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
              padding: EdgeInsets.all(24),
              child: Text('ページの読み込みに失敗しました。'),
            ),
          ),
        ),
      ),
    );
  }
}

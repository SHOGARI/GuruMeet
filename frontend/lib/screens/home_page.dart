import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../widgets/app_shell.dart';
import '../widgets/hero_card_stack.dart';
import '../widgets/primary_action_button.dart';
import 'create_group_page.dart';
import 'join_group_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static const routeName = '/';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const double _mobileContentWidth = 540;
  static const double _desktopContentWidth = 1040;
  static const double _ctaMaxWidth = 440;

  bool _isNavigating = false;

  Future<void> _openRoute(String routeName) async {
    if (_isNavigating) {
      return;
    }
    setState(() => _isNavigating = true);
    await Navigator.of(context).pushNamed(routeName);
    if (mounted) {
      setState(() => _isNavigating = false);
    }
  }

  Future<void> _openCreateGroup() => _openRoute(CreateGroupPage.routeName);

  Future<void> _openJoinGroup() => _openRoute(JoinGroupPage.routeName);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final screenSize = MediaQuery.sizeOf(context);
    final screenWidth = screenSize.width;
    final isDesktop = screenWidth >= 900;
    final verticalGap = screenSize.height < 860
        ? AppSpacing.large
        : AppSpacing.xxLarge;
    final headlineStyle = screenWidth < AppBreakpoints.compact
        ? theme.textTheme.headlineLarge
        : theme.textTheme.displaySmall;

    return AppShell(
      maxContentWidth: screenWidth >= 900
          ? _desktopContentWidth
          : _mobileContentWidth,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.pageEntrance,
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, AppSpacing.regular * (1 - value)),
              child: child,
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  child: Image.asset(
                    'assets/images/gurumeet_icon.png',
                    width: 32,
                    height: 32,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                const SizedBox(width: AppSpacing.small),
                Text(
                  'GuruMeet',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.primary,
                    letterSpacing: AppSizes.codeLabelLetterSpacing,
                  ),
                ),
              ],
            ),
            SizedBox(height: isDesktop ? AppSpacing.xxLarge : AppSpacing.large),
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _HomeIntro(
                      headlineStyle: headlineStyle,
                      onCreateGroup: _isNavigating ? null : _openCreateGroup,
                      onJoinGroup: _isNavigating ? null : _openJoinGroup,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.display),
                  const Expanded(child: HeroCardStack()),
                ],
              )
            else ...[
              _HomeIntroText(headlineStyle: headlineStyle),
              SizedBox(height: verticalGap),
              Align(
                alignment: Alignment.center,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const HeroCardStack(),
                    const SizedBox(height: AppSpacing.large),
                    _HomeActions(
                      onCreateGroup: _isNavigating ? null : _openCreateGroup,
                      onJoinGroup: _isNavigating ? null : _openJoinGroup,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeIntro extends StatelessWidget {
  const _HomeIntro({
    required this.headlineStyle,
    required this.onCreateGroup,
    required this.onJoinGroup,
  });

  final TextStyle? headlineStyle;
  final VoidCallback? onCreateGroup;
  final VoidCallback? onJoinGroup;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeIntroText(headlineStyle: headlineStyle),
        const SizedBox(height: AppSpacing.section),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: _HomePageState._ctaMaxWidth,
            child: _HomeActions(
              onCreateGroup: onCreateGroup,
              onJoinGroup: onJoinGroup,
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeIntroText extends StatelessWidget {
  const _HomeIntroText({required this.headlineStyle});

  final TextStyle? headlineStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('今日どこ行く？', style: headlineStyle?.copyWith(letterSpacing: 0)),
        const SizedBox(height: AppSpacing.small),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Text(
            '友だちと候補を見て、直感で選ぶ。',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeActions extends StatelessWidget {
  const _HomeActions({required this.onCreateGroup, required this.onJoinGroup});

  final VoidCallback? onCreateGroup;
  final VoidCallback? onJoinGroup;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: _HomePageState._ctaMaxWidth,
        ),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: PrimaryActionButton(
                label: 'グループを作る',
                onPressed: onCreateGroup,
              ),
            ),
            const SizedBox(height: AppSpacing.regular),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onJoinGroup,
                child: const Text('コードで参加する'),
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
            Text(
              '共有されたURLまたはコードから参加できます',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

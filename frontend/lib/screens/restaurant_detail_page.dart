import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/group_creation_draft.dart';
import '../models/restaurant_preview.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_shell.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/restaurant_image.dart';
import 'home_page.dart';

class RestaurantDetailPage extends StatefulWidget {
  const RestaurantDetailPage({
    super.key,
    required this.draft,
    required this.restaurant,
  });

  static const routeName = '/restaurant-detail';

  final GroupCreationDraft draft;
  final RestaurantPreview restaurant;

  @override
  State<RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<RestaurantDetailPage> {
  bool _isOpeningMaps = false;
  bool _isNavigating = false;

  GroupCreationDraft get draft => widget.draft;
  RestaurantPreview get restaurant => widget.restaurant;

  Future<void> _openMaps() async {
    if (_isOpeningMaps) {
      return;
    }
    setState(() => _isOpeningMaps = true);
    final query = Uri.encodeComponent(
      '${restaurant.name} ${restaurant.address}',
    );
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Googleマップを開けませんでした')));
    }
    if (mounted) {
      setState(() => _isOpeningMaps = false);
    }
  }

  void _goHome() {
    if (_isNavigating) {
      return;
    }
    setState(() => _isNavigating = true);
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(HomePage.routeName, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AppShell(
      appBar: AppBar(title: const Text('店舗詳細')),
      maxContentWidth: AppSizes.homeMaxWidth,
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryActionButton(
            label: 'Googleマップで開く',
            onPressed: _isOpeningMaps || _isNavigating ? null : _openMaps,
            isLoading: _isOpeningMaps,
            loadingLabel: 'マップを開いています',
          ),
          const SizedBox(height: AppSpacing.small),
          OutlinedButton(
            onPressed: _isNavigating || _isOpeningMaps ? null : _goHome,
            child: const Text('ホームへ戻る'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: RestaurantImage(
                imageUrl: restaurant.imageUrl,
                semanticLabel: '${restaurant.name}の料理写真',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xLarge),
          Text(
            '選ばれたお店',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.primary,
              letterSpacing: AppSizes.codeLabelLetterSpacing,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          Text(restaurant.name, style: theme.textTheme.headlineLarge),
          const SizedBox(height: AppSpacing.small),
          Text(
            '${restaurant.cuisine}  ·  ${restaurant.area}',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.micro),
          Text(
            restaurant.budget,
            style: theme.textTheme.titleMedium?.copyWith(color: colors.primary),
          ),
          const SizedBox(height: AppSpacing.xLarge),
          Text(restaurant.description, style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.section),
          _DetailRow(label: 'グループID', value: draft.groupId),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.medium),
            child: Divider(),
          ),
          _DetailRow(label: '人数', value: '${draft.peopleCount}人'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.medium),
            child: Divider(),
          ),
          _DetailRow(label: '希望エリア', value: draft.area),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.medium),
            child: Divider(),
          ),
          _DetailRow(label: '希望予算', value: draft.budget.label),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: AppSizes.summaryLabelWidth,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.medium),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

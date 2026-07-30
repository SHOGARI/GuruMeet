import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/group_creation_draft.dart';
import '../models/restaurant_preview.dart';
import '../models/room_member.dart';
import '../services/room_repository.dart';
import '../services/user_error_messages.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_shell.dart';
import '../widgets/restaurant_image.dart';
import 'match_page.dart';

class SwipePage extends StatefulWidget {
  const SwipePage({super.key, required this.draft});

  static const routeName = '/swipe';

  final GroupCreationDraft draft;

  @override
  State<SwipePage> createState() => _SwipePageState();
}

class _SwipePageState extends State<SwipePage> {
  final RoomRepository _roomRepository = RoomRepositoryProvider.instance;

  int _currentIndex = 0;
  final List<VoteChoice> _localChoices = [];
  _SwipeChoice? _lastChoice;
  List<RestaurantPreview> _restaurants = const [];
  List<RoomMember> _votingMembers = const [];
  int _restoredPhotoIndex = 0;
  bool _isLoadingRestaurants = true;
  bool _isResolvingChoice = false;
  bool _isComplete = false;
  bool _isOpeningResult = false;
  bool _isOpeningMaps = false;
  bool _isOpeningDetails = false;
  bool _isLoadingVotingStatus = false;
  String? _restaurantLoadError;
  Timer? _completionTimer;

  RestaurantPreview get _currentRestaurant => _restaurants[_currentIndex];
  int get _remainingCount =>
      _isComplete ? 0 : _restaurants.length - _currentIndex;
  int get _completedVotingCount =>
      _votingMembers.where((member) => member.hasCompletedVoting).length;
  bool get _isAllVotingComplete =>
      _votingMembers.isNotEmpty &&
      _completedVotingCount == _votingMembers.length;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRestaurants());
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRestaurants() async {
    setState(() {
      _isLoadingRestaurants = true;
      _restaurantLoadError = null;
    });
    try {
      final restaurants = await _roomRepository.getRestaurantCandidates(
        widget.draft,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _restaurants = restaurants;
        _isLoadingRestaurants = false;
      });
      unawaited(_precacheUpcomingRestaurants(0));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingRestaurants = false;
        _restaurantLoadError = votingErrorMessage(error);
      });
    }
  }

  Future<void> _chooseRestaurant({
    required bool liked,
    required int photoIndex,
  }) async {
    if (_isResolvingChoice ||
        _isComplete ||
        _currentIndex >= _restaurants.length) {
      return;
    }
    setState(() => _isResolvingChoice = true);
    final previousLastChoice = _lastChoice;
    final selectedIndex = _currentIndex;
    final currentRestaurant = _currentRestaurant;
    final voteChoice = VoteChoice(
      restaurantId: currentRestaurant.id,
      liked: liked,
    );
    final choice = _SwipeChoice(
      restaurantIndex: _currentIndex,
      restaurantId: currentRestaurant.id,
      liked: liked,
      photoIndex: photoIndex,
    );
    final isLastRestaurant = selectedIndex == _restaurants.length - 1;

    _localChoices.add(voteChoice);
    setState(() {
      _lastChoice = choice;
      _restoredPhotoIndex = 0;
      if (isLastRestaurant) {
        _isComplete = true;
      } else {
        _currentIndex = selectedIndex + 1;
      }
    });
    if (!isLastRestaurant) {
      unawaited(_precacheUpcomingRestaurants(selectedIndex + 1));
    }

    try {
      await _roomRepository.submitVote(draft: widget.draft, choice: voteChoice);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _removeLocalVote(choice);
      setState(() {
        _currentIndex = selectedIndex;
        _lastChoice = previousLastChoice;
        _restoredPhotoIndex = photoIndex;
        _isComplete = false;
        _isResolvingChoice = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(votingErrorMessage(error))));
      return;
    }

    if (isLastRestaurant) {
      try {
        final votingStatus = await _roomRepository.getVotingStatus(
          widget.draft,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _votingMembers = votingStatus.members;
          _isResolvingChoice = false;
        });
      } catch (error) {
        if (!mounted) {
          return;
        }
        setState(() => _isResolvingChoice = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(votingErrorMessage(error))));
      }
      _startCompletionSimulation();
      return;
    }

    if (mounted) {
      setState(() => _isResolvingChoice = false);
    }
  }

  Future<void> _precacheUpcomingRestaurants(int startIndex) async {
    if (!mounted || _restaurants.isEmpty) {
      return;
    }
    final cacheWidth = restaurantImageCacheWidth(context);
    final lastIndex = (startIndex + 1).clamp(0, _restaurants.length - 1);
    final providers = <ImageProvider<Object>>[];
    for (var index = startIndex; index <= lastIndex; index++) {
      final urls = _restaurants[index].imageUrls;
      if (urls.isEmpty) {
        continue;
      }
      final photoLimit = index == startIndex ? 2 : 1;
      for (final url in urls.take(photoLimit)) {
        final provider = restaurantImageProvider(url, cacheWidth: cacheWidth);
        if (provider != null) {
          providers.add(provider);
        }
      }
    }
    await Future.wait(
      providers.map(
        (provider) =>
            precacheImage(provider, context, onError: (error, stackTrace) {}),
      ),
    );
  }

  void _undoLastChoice() {
    final choice = _lastChoice;
    if (choice == null || _isResolvingChoice || _isOpeningResult) {
      return;
    }

    _removeLocalVote(choice);
    setState(() {
      _currentIndex = choice.restaurantIndex;
      _lastChoice = null;
      _votingMembers = const [];
      _restoredPhotoIndex = choice.photoIndex;
      _isComplete = false;
      _isResolvingChoice = false;
    });
    _completionTimer?.cancel();
  }

  void _removeLocalVote(_SwipeChoice choice) {
    final lastIndex = _localChoices.lastIndexWhere(
      (vote) => vote.restaurantId == choice.restaurantId,
    );
    if (lastIndex != -1) {
      _localChoices.removeAt(lastIndex);
    }
  }

  Future<void> _openResult() async {
    if (_isOpeningResult || !_isComplete || !_isAllVotingComplete) {
      return;
    }
    setState(() => _isOpeningResult = true);
    _completionTimer?.cancel();
    try {
      final latestResult = await _roomRepository.getResult(
        draft: widget.draft,
        restaurants: _restaurants,
        localChoices: _localChoices,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed(
        MatchPage.routeName,
        arguments: (draft: widget.draft, result: latestResult),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isOpeningResult = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(votingErrorMessage(error))));
    }
  }

  void _startCompletionSimulation() {
    _completionTimer?.cancel();
    _completionTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (!mounted) {
        _completionTimer?.cancel();
        return;
      }
      if (!_isComplete || _isOpeningResult || _isAllVotingComplete) {
        _completionTimer?.cancel();
        return;
      }
      unawaited(_loadVotingStatus());
    });
  }

  Future<void> _loadVotingStatus() async {
    if (_isLoadingVotingStatus) {
      return;
    }
    _isLoadingVotingStatus = true;
    try {
      final status = await _roomRepository.getVotingStatus(widget.draft);
      if (!mounted) {
        return;
      }
      setState(() => _votingMembers = status.members);
      if (status.isComplete) {
        _completionTimer?.cancel();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(votingErrorMessage(error))));
    } finally {
      _isLoadingVotingStatus = false;
    }
  }

  Future<void> _showRestaurantDetails(RestaurantPreview restaurant) async {
    if (_isOpeningDetails) {
      return;
    }
    setState(() => _isOpeningDetails = true);
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _RestaurantDetailSheet(
          restaurant: restaurant,
          onOpenMaps: () => _openMaps(restaurant),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningDetails = false);
      }
    }
  }

  Future<void> _openMaps(RestaurantPreview restaurant) async {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AppShell(
      appBar: AppBar(title: const Text('お店を選ぶ')),
      maxContentWidth: AppSizes.homeMaxWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('食べたい？', style: theme.textTheme.headlineMedium),
              ),
              if (!_isLoadingRestaurants && _restaurants.isNotEmpty)
                _RemainingBadge(
                  remainingCount: _remainingCount,
                  totalCount: _restaurants.length,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.small),
          if (_isLoadingRestaurants)
            const LinearProgressIndicator()
          else if (_restaurants.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.small),
              child: LinearProgressIndicator(
                minHeight: AppSizes.progressIndicatorHeight,
                value: _isComplete
                    ? 1
                    : (_currentIndex + 1) / _restaurants.length,
                backgroundColor: colors.surfaceContainerHigh,
              ),
            ),
          const SizedBox(height: AppSpacing.regular),
          const _SwipeHelpText(),
          const SizedBox(height: AppSpacing.regular),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.restaurantCardMaxWidth,
              ),
              child: AnimatedSwitcher(
                duration: AppMotion.medium,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                child: _isLoadingRestaurants
                    ? const _SwipeNoticeCard(
                        key: ValueKey('restaurant-loading'),
                        icon: Icons.restaurant_menu_rounded,
                        title: '店舗候補を探しています',
                        message: '条件に合うお店を読み込んでいます。',
                      )
                    : _restaurantLoadError != null
                    ? _SwipeNoticeCard(
                        key: const ValueKey('restaurant-error'),
                        icon: Icons.error_outline_rounded,
                        title: '読み込みに失敗しました',
                        message: _restaurantLoadError!,
                        actionLabel: '再読み込み',
                        onAction: () => unawaited(_loadRestaurants()),
                      )
                    : _restaurants.isEmpty
                    ? _SwipeNoticeCard(
                        key: ValueKey('restaurant-empty'),
                        icon: Icons.search_off_rounded,
                        title: '候補が見つかりませんでした',
                        message: 'エリアや予算を変えてもう一度作成してください。',
                        actionLabel: '戻る',
                        onAction: () => Navigator.of(context).maybePop(),
                      )
                    : _isComplete
                    ? _CompletionCard(
                        key: const ValueKey('swipe-complete'),
                        members: _votingMembers,
                        onOpenResult: _isOpeningResult || !_isAllVotingComplete
                            ? null
                            : () => unawaited(_openResult()),
                      )
                    : _SwipeCard(
                        key: ValueKey(_currentRestaurant.id),
                        restaurant: _currentRestaurant,
                        initialPhotoIndex: _restoredPhotoIndex,
                        isResolvingChoice:
                            _isResolvingChoice || _isOpeningDetails,
                        onShowDetails: () =>
                            _showRestaurantDetails(_currentRestaurant),
                        onSelected: (liked, photoIndex) => _chooseRestaurant(
                          liked: liked,
                          photoIndex: photoIndex,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.regular),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.restaurantCardMaxWidth,
              ),
              child: _SwipeFooterActions(
                canUndo:
                    _lastChoice != null &&
                    !_isResolvingChoice &&
                    !_isOpeningResult,
                onUndo: _undoLastChoice,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeChoice {
  const _SwipeChoice({
    required this.restaurantIndex,
    required this.restaurantId,
    required this.liked,
    required this.photoIndex,
  });

  final int restaurantIndex;
  final String restaurantId;
  final bool liked;
  final int photoIndex;
}

class _RemainingBadge extends StatelessWidget {
  const _RemainingBadge({
    required this.remainingCount,
    required this.totalCount,
  });

  final int remainingCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AnimatedSwitcher(
      duration: AppMotion.quick,
      child: Container(
        key: ValueKey(remainingCount),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.small,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Text(
          '残り $remainingCount / $totalCount',
          style: theme.textTheme.titleSmall?.copyWith(color: colors.primary),
        ),
      ),
    );
  }
}

class _SwipeFooterActions extends StatelessWidget {
  const _SwipeFooterActions({required this.canUndo, required this.onUndo});

  final bool canUndo;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: canUndo ? onUndo : null,
          icon: const Icon(Icons.undo_rounded),
          label: const Text('ひとつ戻す'),
        ),
        const SizedBox(height: AppSpacing.micro),
        Text(
          canUndo ? '直前の選択を取り消せます' : '選ぶと、ここから1回だけ戻せます',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SwipeHelpText extends StatelessWidget {
  const _SwipeHelpText();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Icon(Icons.swipe_rounded, color: colors.primary, size: 18),
        const SizedBox(width: AppSpacing.small),
        Expanded(
          child: Text(
            '右で食べたい、左で見送り',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          '写真は左右タップ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SwipeNoticeCard extends StatelessWidget {
  const _SwipeNoticeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.large),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: colors.primary),
          const SizedBox(height: AppSpacing.medium),
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.small),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          if (actionLabel case final label?) ...[
            const SizedBox(height: AppSpacing.medium),
            FilledButton.tonal(onPressed: onAction, child: Text(label)),
          ],
        ],
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({
    super.key,
    required this.members,
    required this.onOpenResult,
  });

  final List<RoomMember> members;
  final VoidCallback? onOpenResult;

  int get _completedCount =>
      members.where((member) => member.hasCompletedVoting).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final progress = members.isEmpty ? 0.0 : _completedCount / members.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.large),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, color: colors.onPrimary),
          ),
          const SizedBox(height: AppSpacing.medium),
          Text('投票完了', style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.micro),
          Text(
            'みんなの投票を待っています',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          Text(
            '$_completedCount / ${members.length}人 完了',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: AppSizes.progressIndicatorHeight,
              backgroundColor: colors.surfaceContainerHigh,
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          ...members.map(
            (member) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.micro),
              child: _VotingMemberTile(member: member),
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onOpenResult,
              icon: const Icon(Icons.bar_chart_rounded),
              label: const Text('結果を見る'),
            ),
          ),
        ],
      ),
    );
  }
}

class _VotingMemberTile extends StatelessWidget {
  const _VotingMemberTile({required this.member});

  final RoomMember member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final completed = member.hasCompletedVoting;

    return AnimatedContainer(
      duration: AppMotion.medium,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.regular,
      ),
      decoration: BoxDecoration(
        color: completed ? colors.primaryContainer : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: completed
                ? colors.primary
                : colors.surfaceContainerHighest,
            foregroundColor: completed
                ? colors.onPrimary
                : colors.onSurfaceVariant,
            backgroundImage: member.avatarUrl == null
                ? null
                : NetworkImage(member.avatarUrl!),
            child: member.avatarUrl == null
                ? Icon(
                    member.isHost ? Icons.star_rounded : Icons.person_rounded,
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.regular),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    member.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (member.isHost) ...[
                  const SizedBox(width: AppSpacing.small),
                  _TinyStatusPill(label: 'ホスト', completed: completed),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.small),
          _TinyStatusPill(
            label: completed ? '完了' : '未完了',
            completed: completed,
          ),
        ],
      ),
    );
  }
}

class _TinyStatusPill extends StatelessWidget {
  const _TinyStatusPill({required this.label, required this.completed});

  final String label;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.small,
        vertical: AppSpacing.micro,
      ),
      decoration: BoxDecoration(
        color: completed
            ? colors.primary.withValues(alpha: 0.16)
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: completed ? colors.primary : colors.onSurfaceVariant,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RestaurantDetailSheet extends StatelessWidget {
  const _RestaurantDetailSheet({
    required this.restaurant,
    required this.onOpenMaps,
  });

  final RestaurantPreview restaurant;
  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.44,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.card),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xLarge,
              AppSpacing.medium,
              AppSpacing.xLarge,
              AppSpacing.xLarge,
            ),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xLarge),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.small),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: RestaurantImage(
                    imageUrl: restaurant.imageUrl,
                    semanticLabel: '${restaurant.name}の料理写真',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xLarge),
              Text(restaurant.name, style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.small),
              Text(
                restaurant.description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xLarge),
              _SheetDetailRow(label: 'ジャンル', value: restaurant.cuisine),
              _SheetDetailRow(label: '予算', value: restaurant.budget),
              _SheetDetailRow(label: '距離', value: restaurant.distance),
              _SheetDetailRow(label: '営業時間', value: restaurant.openingHours),
              _SheetDetailRow(label: '住所', value: restaurant.address),
              const SizedBox(height: AppSpacing.xLarge),
              FilledButton.icon(
                onPressed: onOpenMaps,
                icon: const Icon(Icons.map_rounded),
                label: const Text('Googleマップを開く'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SheetDetailRow extends StatelessWidget {
  const _SheetDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.regular),
      child: Row(
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
              style: theme.textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeCard extends StatefulWidget {
  const _SwipeCard({
    super.key,
    required this.restaurant,
    required this.initialPhotoIndex,
    required this.isResolvingChoice,
    required this.onShowDetails,
    required this.onSelected,
  });

  final RestaurantPreview restaurant;
  final int initialPhotoIndex;
  final bool isResolvingChoice;
  final VoidCallback onShowDetails;
  final void Function(bool liked, int photoIndex) onSelected;

  @override
  State<_SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<_SwipeCard>
    with SingleTickerProviderStateMixin {
  static const double _decisionDistance = 116;
  static const double _flyDistance = 760;
  static const double _maxRotation = 0.22;

  late final AnimationController _controller;
  Animation<Offset>? _offsetAnimation;
  final ValueNotifier<Offset> _dragOffset = ValueNotifier(Offset.zero);
  int _photoIndex = 0;
  bool _isAnimatingOut = false;

  bool get _isInteractionLocked => widget.isResolvingChoice || _isAnimatingOut;

  @override
  void initState() {
    super.initState();
    _photoIndex = widget.initialPhotoIndex;
    _controller = AnimationController(vsync: this, duration: AppMotion.medium)
      ..addListener(() {
        final animation = _offsetAnimation;
        if (animation == null) {
          return;
        }
        _dragOffset.value = animation.value;
      });
  }

  @override
  void didUpdateWidget(covariant _SwipeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restaurant.id != widget.restaurant.id) {
      _controller.stop();
      _offsetAnimation = null;
      _dragOffset.value = Offset.zero;
      _photoIndex = widget.initialPhotoIndex;
      _isAnimatingOut = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _dragOffset.dispose();
    super.dispose();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_isInteractionLocked) {
      return;
    }
    _dragOffset.value += details.delta;
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_isInteractionLocked) {
      return;
    }

    final velocity = details.velocity.pixelsPerSecond.dx;
    final shouldChoose =
        _dragOffset.value.dx.abs() > _decisionDistance || velocity.abs() > 720;
    if (!shouldChoose) {
      _animateTo(Offset.zero);
      return;
    }

    _animateOut(liked: _dragOffset.value.dx > 0 || velocity > 0);
  }

  void _animateTo(Offset target) {
    _offsetAnimation = Tween<Offset>(
      begin: _dragOffset.value,
      end: target,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller
      ..duration = AppMotion.medium
      ..forward(from: 0);
  }

  void _animateOut({required bool liked}) {
    if (_isInteractionLocked) {
      return;
    }

    setState(() => _isAnimatingOut = true);
    final direction = liked ? 1.0 : -1.0;
    _offsetAnimation = Tween<Offset>(
      begin: _dragOffset.value,
      end: Offset(direction * _flyDistance, _dragOffset.value.dy - 80),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInCubic));
    _controller
      ..duration = const Duration(milliseconds: 260)
      ..forward(from: 0).whenComplete(() {
        if (!mounted) {
          return;
        }
        widget.onSelected(liked, _photoIndex);
      });
  }

  void _showPreviousPhoto() {
    if (_isInteractionLocked || widget.restaurant.imageUrls.length < 2) {
      return;
    }
    setState(() {
      _photoIndex =
          (_photoIndex - 1 + widget.restaurant.imageUrls.length) %
          widget.restaurant.imageUrls.length;
    });
  }

  void _showNextPhoto() {
    if (_isInteractionLocked || widget.restaurant.imageUrls.length < 2) {
      return;
    }
    setState(() {
      _photoIndex = (_photoIndex + 1) % widget.restaurant.imageUrls.length;
    });
  }

  void _handleTapUp(TapUpDetails details, Size size) {
    if (details.localPosition.dy > size.height - 120) {
      return;
    }
    if (details.localPosition.dy > size.height - 204 &&
        details.localPosition.dx > size.width * 0.3 &&
        details.localPosition.dx < size.width * 0.7) {
      return;
    }

    if (details.localPosition.dx < size.width / 2) {
      _showPreviousPhoto();
      return;
    }
    _showNextPhoto();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Offset>(
      valueListenable: _dragOffset,
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardSize = Size(
              constraints.maxWidth,
              constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : constraints.maxWidth * 1.25,
            );
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _handleTapUp(details, cardSize),
              child: _CardSurface(
                restaurant: widget.restaurant,
                photoIndex: _photoIndex,
                isResolvingChoice: _isInteractionLocked,
                onShowDetails: widget.onShowDetails,
                onRejected: () => _animateOut(liked: false),
                onLiked: () => _animateOut(liked: true),
              ),
            );
          },
        ),
      ),
      builder: (context, dragOffset, child) {
        final rotation = (dragOffset.dx / 420).clamp(
          -_maxRotation,
          _maxRotation,
        );
        final decisionProgress = (dragOffset.dx.abs() / _decisionDistance)
            .clamp(0.0, 1.0);
        final likeOpacity = dragOffset.dx > 0 ? decisionProgress : 0.0;
        final rejectOpacity = dragOffset.dx < 0 ? decisionProgress : 0.0;
        return Transform.translate(
          offset: dragOffset,
          child: Transform.rotate(
            angle: rotation,
            child: GestureDetector(
              onHorizontalDragUpdate: _handlePanUpdate,
              onHorizontalDragEnd: _handlePanEnd,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  child!,
                  Positioned(
                    left: AppSpacing.xLarge,
                    top: AppSpacing.xLarge + AppSpacing.large,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: likeOpacity,
                        child: Transform.rotate(
                          angle: -0.12,
                          child: const _DecisionStamp(
                            label: '行きたい',
                            icon: Icons.bookmark_add_rounded,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: AppSpacing.xLarge,
                    top: AppSpacing.xLarge + AppSpacing.large,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: rejectOpacity,
                        child: Transform.rotate(
                          angle: 0.12,
                          child: const _DecisionStamp(
                            label: '今回は見送る',
                            icon: Icons.do_not_disturb_alt_rounded,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CardSurface extends StatelessWidget {
  const _CardSurface({
    required this.restaurant,
    required this.photoIndex,
    required this.isResolvingChoice,
    required this.onShowDetails,
    required this.onRejected,
    required this.onLiked,
  });

  final RestaurantPreview restaurant;
  final int photoIndex;
  final bool isResolvingChoice;
  final VoidCallback onShowDetails;
  final VoidCallback onRejected;
  final VoidCallback onLiked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final imageUrls = restaurant.imageUrls.isEmpty
        ? [restaurant.imageUrl]
        : restaurant.imageUrls;
    final visiblePhotoIndex = photoIndex.clamp(0, imageUrls.length - 1);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Transform.translate(
            offset: const Offset(0, 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Transform.translate(
            offset: const Offset(0, 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
            ),
          ),
        ),
        Material(
          color: colors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          elevation: 0,
          shadowColor: colors.shadow,
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 9 / 12,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedSwitcher(
                  duration: AppMotion.medium,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  child: RestaurantImage(
                    key: ValueKey('${restaurant.id}-$photoIndex'),
                    imageUrl: imageUrls[visiblePhotoIndex],
                    semanticLabel: '${restaurant.name}の料理写真',
                  ),
                ),
                Positioned(
                  left: AppSpacing.medium,
                  right: AppSpacing.medium,
                  top: AppSpacing.medium,
                  child: _PhotoProgress(
                    count: imageUrls.length,
                    index: visiblePhotoIndex,
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.12),
                        Colors.black.withValues(alpha: 0.78),
                      ],
                      stops: const [0.4, 0.62, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: AppSpacing.xLarge,
                  right: AppSpacing.xLarge,
                  bottom: 118,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        restaurant.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.32),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.small),
                      Wrap(
                        spacing: AppSpacing.small,
                        runSpacing: AppSpacing.small,
                        children: [
                          _InfoPill(label: restaurant.cuisine),
                          _InfoPill(label: restaurant.area),
                          _InfoPill(label: restaurant.budget),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.small),
                      Text(
                        restaurant.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 72,
                  child: Center(
                    child: TextButton.icon(
                      onPressed: isResolvingChoice ? null : onShowDetails,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.black.withValues(alpha: 0.34),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.medium,
                          vertical: AppSpacing.small,
                        ),
                      ),
                      icon: const Icon(Icons.expand_less_rounded),
                      label: const Text('詳細を見る'),
                    ),
                  ),
                ),
                Positioned(
                  left: AppSpacing.xLarge,
                  right: AppSpacing.xLarge,
                  bottom: AppSpacing.regular,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SwipeActionButton(
                        tooltip: '今回は見送る',
                        icon: Icons.do_not_disturb_alt_rounded,
                        foregroundColor: colors.onErrorContainer,
                        backgroundColor: colors.errorContainer,
                        onPressed: isResolvingChoice ? null : onRejected,
                      ),
                      _SwipeActionButton(
                        tooltip: '行きたい',
                        icon: Icons.bookmark_add_rounded,
                        foregroundColor: colors.onPrimary,
                        backgroundColor: colors.primary,
                        onPressed: isResolvingChoice ? null : onLiked,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoProgress extends StatelessWidget {
  const _PhotoProgress({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (itemIndex) {
        return Expanded(
          child: AnimatedContainer(
            duration: AppMotion.quick,
            height: 4,
            margin: EdgeInsets.only(
              left: itemIndex == 0 ? 0 : AppSpacing.micro,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: itemIndex == index ? 0.95 : 0.32,
              ),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
          ),
        );
      }),
    );
  }
}

class _DecisionStamp extends StatelessWidget {
  const _DecisionStamp({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 4),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.small,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: AppSizes.iconMedium),
            const SizedBox(width: AppSpacing.small),
            Text(
              label,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.small,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SwipeActionButton extends StatelessWidget {
  const _SwipeActionButton({
    required this.tooltip,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton.filled(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(68),
          foregroundColor: foregroundColor,
          backgroundColor: backgroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.52),
          disabledForegroundColor: foregroundColor.withValues(alpha: 0.52),
          shape: const CircleBorder(),
        ),
        iconSize: 28,
        icon: Icon(icon),
      ),
    );
  }
}

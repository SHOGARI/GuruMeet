import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../models/group_creation_draft.dart';
import '../models/location_suggestion.dart';
import '../services/location_repository.dart';
import '../services/room_repository.dart';
import '../services/user_error_messages.dart';
import '../theme/app_tokens.dart';
import '../widgets/primary_action_button.dart';
import 'group_created_page.dart';

const _prefectureOptions = <String>[
  '北海道',
  '青森県',
  '岩手県',
  '宮城県',
  '秋田県',
  '山形県',
  '福島県',
  '茨城県',
  '栃木県',
  '群馬県',
  '埼玉県',
  '千葉県',
  '東京都',
  '神奈川県',
  '新潟県',
  '富山県',
  '石川県',
  '福井県',
  '山梨県',
  '長野県',
  '岐阜県',
  '静岡県',
  '愛知県',
  '三重県',
  '滋賀県',
  '京都府',
  '大阪府',
  '兵庫県',
  '奈良県',
  '和歌山県',
  '鳥取県',
  '島根県',
  '岡山県',
  '広島県',
  '山口県',
  '徳島県',
  '香川県',
  '愛媛県',
  '高知県',
  '福岡県',
  '佐賀県',
  '長崎県',
  '熊本県',
  '大分県',
  '宮崎県',
  '鹿児島県',
  '沖縄県',
];

const _prefectureKanaByName = <String, String>{
  '北海道': 'ほっかいどう',
  '青森県': 'あおもりけん',
  '岩手県': 'いわてけん',
  '宮城県': 'みやぎけん',
  '秋田県': 'あきたけん',
  '山形県': 'やまがたけん',
  '福島県': 'ふくしまけん',
  '茨城県': 'いばらきけん',
  '栃木県': 'とちぎけん',
  '群馬県': 'ぐんまけん',
  '埼玉県': 'さいたまけん',
  '千葉県': 'ちばけん',
  '東京都': 'とうきょうと',
  '神奈川県': 'かながわけん',
  '新潟県': 'にいがたけん',
  '富山県': 'とやまけん',
  '石川県': 'いしかわけん',
  '福井県': 'ふくいけん',
  '山梨県': 'やまなしけん',
  '長野県': 'ながのけん',
  '岐阜県': 'ぎふけん',
  '静岡県': 'しずおかけん',
  '愛知県': 'あいちけん',
  '三重県': 'みえけん',
  '滋賀県': 'しがけん',
  '京都府': 'きょうとふ',
  '大阪府': 'おおさかふ',
  '兵庫県': 'ひょうごけん',
  '奈良県': 'ならけん',
  '和歌山県': 'わかやまけん',
  '鳥取県': 'とっとりけん',
  '島根県': 'しまねけん',
  '岡山県': 'おかやまけん',
  '広島県': 'ひろしまけん',
  '山口県': 'やまぐちけん',
  '徳島県': 'とくしまけん',
  '香川県': 'かがわけん',
  '愛媛県': 'えひめけん',
  '高知県': 'こうちけん',
  '福岡県': 'ふくおかけん',
  '佐賀県': 'さがけん',
  '長崎県': 'ながさきけん',
  '熊本県': 'くまもとけん',
  '大分県': 'おおいたけん',
  '宮崎県': 'みやざきけん',
  '鹿児島県': 'かごしまけん',
  '沖縄県': 'おきなわけん',
};

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  static const routeName = '/create-group';

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final RoomRepository _roomRepository = RoomRepositoryProvider.instance;
  final _formKey = GlobalKey<FormState>();
  final _prefectureController = TextEditingController();
  final _areaController = TextEditingController();
  final _areaFocusNode = FocusNode();

  String? _selectedPrefecture;
  LocationSuggestion? _selectedLocation;
  int _peopleCount = 4;
  BudgetOption? _selectedBudget = BudgetOption.from2000To3000;
  bool _hasTriedSubmit = false;
  bool _isSubmitting = false;
  bool _isReadingLocation = false;

  @override
  void dispose() {
    _prefectureController.dispose();
    _areaController.dispose();
    _areaFocusNode.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (_isSubmitting) {
      return;
    }

    setState(() => _hasTriedSubmit = true);

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      _areaFocusNode.requestFocus();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('エリアを入力するとグループを作成できます')));
      return;
    }

    final selectedBudget = _selectedBudget;
    if (selectedBudget == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('予算を選んでください')));
      return;
    }

    setState(() => _isSubmitting = true);
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final draft = await _roomRepository.createRoom(
        peopleCount: _peopleCount,
        area: _selectedLocation?.displayName ?? _areaController.text.trim(),
        budget: selectedBudget,
        locationId: _selectedLocation?.id,
      );
      if (!mounted) {
        return;
      }
      await Navigator.of(
        context,
      ).pushNamed(GroupCreatedPage.routeName, arguments: draft);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(roomCreateErrorMessage(error))));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _selectBudget(BudgetOption budget) {
    setState(() => _selectedBudget = budget);
  }

  void _selectLocation(LocationSuggestion? location) {
    setState(() {
      _selectedLocation = location;
      _selectedPrefecture = location?.prefecture ?? _selectedPrefecture;
    });
  }

  void _selectPrefecture(String? prefecture) {
    setState(() {
      _selectedPrefecture = prefecture;
      _selectedLocation = null;
      _areaController.clear();
    });
    if (prefecture != null) {
      _areaFocusNode.requestFocus();
    }
  }

  Future<void> _readAreaFromLocation() async {
    if (_isReadingLocation) {
      return;
    }

    setState(() => _isReadingLocation = true);
    FocusManager.instance.primaryFocus?.unfocus();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationSnackBar('位置情報サービスをオンにしてください');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showLocationSnackBar('位置情報の許可が必要です');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationSnackBar('設定から位置情報の許可をオンにしてください');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      final placemarks = await Geocoding(
        locale: const Locale('ja', 'JP'),
      ).placemarkFromCoordinates(position.latitude, position.longitude);
      final placemark = placemarks.isEmpty ? null : placemarks.first;
      final area = _formatAreaFromPlacemark(placemark);

      if (area == null) {
        _showLocationSnackBar('現在地の地名を読み取れませんでした');
        return;
      }

      if (!mounted) {
        return;
      }
      final administrativeArea = placemark?.administrativeArea?.trim();
      final prefecture =
          administrativeArea != null &&
              _prefectureOptions.contains(administrativeArea)
          ? administrativeArea
          : _selectedPrefecture;
      setState(() {
        _selectedPrefecture = prefecture;
        _areaController.text = area;
        _selectedLocation = null;
        _hasTriedSubmit = false;
      });
      _showLocationSnackBar('$area を入力しました。候補から地点を選んでください');
    } catch (_) {
      _showLocationSnackBar('位置情報を読み取れませんでした');
    } finally {
      if (mounted) {
        setState(() => _isReadingLocation = false);
      }
    }
  }

  String? _formatAreaFromPlacemark(Placemark? placemark) {
    if (placemark == null) {
      return null;
    }

    final locality = placemark.locality?.trim();
    final subLocality = placemark.subLocality?.trim();
    final administrativeArea = placemark.administrativeArea?.trim();
    final thoroughfare = placemark.thoroughfare?.trim();

    final primary = _firstFilled([locality, subLocality, administrativeArea]);
    if (primary == null) {
      return _firstFilled([thoroughfare, placemark.name?.trim()]);
    }

    if (subLocality != null &&
        subLocality.isNotEmpty &&
        subLocality != primary) {
      return '$primary $subLocality';
    }

    if (thoroughfare != null &&
        thoroughfare.isNotEmpty &&
        !primary.contains(thoroughfare)) {
      return '$primary $thoroughfare';
    }

    return primary;
  }

  String? _firstFilled(Iterable<String?> values) {
    for (final value in values) {
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  void _showLocationSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < AppBreakpoints.compact
        ? AppSpacing.medium
        : AppSpacing.xLarge;

    return Scaffold(
      appBar: AppBar(title: const Text('グループ作成')),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.large,
            horizontalPadding,
            AppSpacing.large,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.contentMaxWidth,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: _CreateGroupForm(
                        formKey: _formKey,
                        prefectureController: _prefectureController,
                        areaController: _areaController,
                        areaFocusNode: _areaFocusNode,
                        hasTriedSubmit: _hasTriedSubmit,
                        peopleCount: _peopleCount,
                        selectedPrefecture: _selectedPrefecture,
                        selectedLocation: _selectedLocation,
                        selectedBudget: _selectedBudget,
                        isReadingLocation: _isReadingLocation,
                        onAreaSubmitted: _createGroup,
                        onPrefectureSelected: _selectPrefecture,
                        onLocationSelected: _selectLocation,
                        onReadAreaFromLocation: _readAreaFromLocation,
                        onDecreasePeople: _peopleCount > 2
                            ? () => setState(() => _peopleCount--)
                            : null,
                        onIncreasePeople: _peopleCount < 10
                            ? () => setState(() => _peopleCount++)
                            : null,
                        onBudgetSelected: _selectBudget,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.regular),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryActionButton(
                      label: 'グループを作成',
                      onPressed: _isSubmitting ? null : _createGroup,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateGroupForm extends StatelessWidget {
  const _CreateGroupForm({
    required this.formKey,
    required this.prefectureController,
    required this.areaController,
    required this.areaFocusNode,
    required this.hasTriedSubmit,
    required this.peopleCount,
    required this.selectedPrefecture,
    required this.selectedLocation,
    required this.selectedBudget,
    required this.isReadingLocation,
    required this.onAreaSubmitted,
    required this.onPrefectureSelected,
    required this.onLocationSelected,
    required this.onReadAreaFromLocation,
    required this.onDecreasePeople,
    required this.onIncreasePeople,
    required this.onBudgetSelected,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController prefectureController;
  final TextEditingController areaController;
  final FocusNode areaFocusNode;
  final bool hasTriedSubmit;
  final int peopleCount;
  final String? selectedPrefecture;
  final LocationSuggestion? selectedLocation;
  final BudgetOption? selectedBudget;
  final bool isReadingLocation;
  final VoidCallback onAreaSubmitted;
  final ValueChanged<String?> onPrefectureSelected;
  final ValueChanged<LocationSuggestion?> onLocationSelected;
  final VoidCallback onReadAreaFromLocation;
  final VoidCallback? onDecreasePeople;
  final VoidCallback? onIncreasePeople;
  final ValueChanged<BudgetOption> onBudgetSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Form(
      key: formKey,
      autovalidateMode: hasTriedSubmit
          ? AutovalidateMode.always
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('集合をつくる', style: theme.textTheme.headlineLarge),
          const SizedBox(height: AppSpacing.small),
          Text(
            '人数・場所・予算を決めたら、すぐ招待できます。',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xLarge),
          _FormSection(
            step: '01',
            title: '何人で行く？',
            child: _PeopleCounter(
              peopleCount: peopleCount,
              onDecrease: onDecreasePeople,
              onIncrease: onIncreasePeople,
            ),
          ),
          const SizedBox(height: AppSpacing.xLarge),
          _FormSection(
            step: '02',
            title: 'どのあたり？',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PrefectureField(
                  controller: prefectureController,
                  selectedPrefecture: selectedPrefecture,
                  onSelected: onPrefectureSelected,
                ),
                const SizedBox(height: AppSpacing.regular),
                _LocationSearchField(
                  controller: areaController,
                  focusNode: areaFocusNode,
                  selectedPrefecture: selectedPrefecture,
                  selectedLocation: selectedLocation,
                  onSubmitted: onAreaSubmitted,
                  onSelected: onLocationSelected,
                ),
                const SizedBox(height: AppSpacing.regular),
                OutlinedButton.icon(
                  onPressed: isReadingLocation ? null : onReadAreaFromLocation,
                  icon: isReadingLocation
                      ? const SizedBox.square(
                          dimension: AppSizes.iconMedium,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_outlined),
                  label: Text(isReadingLocation ? '読み取り中' : '現在地から入力'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xLarge),
          _FormSection(
            step: '03',
            title: '予算はどれくらい？',
            child: Wrap(
              spacing: AppSpacing.small,
              runSpacing: AppSpacing.small,
              children: BudgetOption.values.map((budget) {
                return _BudgetChoiceChip(
                  label: budget.label,
                  selected: selectedBudget == budget,
                  onSelected: (_) => onBudgetSelected(budget),
                );
              }).toList(),
            ),
          ),
          if (hasTriedSubmit && selectedBudget == null) ...[
            const SizedBox(height: AppSpacing.regular),
            Text(
              '希望の予算を選んでください',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.section),
        ],
      ),
    );
  }
}

class _PrefectureField extends StatelessWidget {
  const _PrefectureField({
    required this.controller,
    required this.selectedPrefecture,
    required this.onSelected,
  });

  final TextEditingController controller;
  final String? selectedPrefecture;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return _SearchablePrefectureField(
      controller: controller,
      selectedPrefecture: selectedPrefecture,
      onSelected: onSelected,
    );
  }
}

class _SearchablePrefectureField extends StatefulWidget {
  const _SearchablePrefectureField({
    required this.controller,
    required this.selectedPrefecture,
    required this.onSelected,
  });

  final TextEditingController controller;
  final String? selectedPrefecture;
  final ValueChanged<String?> onSelected;

  @override
  State<_SearchablePrefectureField> createState() =>
      _SearchablePrefectureFieldState();
}

class _SearchablePrefectureFieldState
    extends State<_SearchablePrefectureField> {
  final _focusNode = FocusNode();

  bool _isApplyingSelection = false;
  List<String> _filteredPrefectures = _prefectureOptions;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChanged);
    _focusNode.addListener(_handleFocusChanged);
    _syncControllerWithSelection();
  }

  @override
  void didUpdateWidget(covariant _SearchablePrefectureField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPrefecture != widget.selectedPrefecture) {
      _syncControllerWithSelection();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _syncControllerWithSelection() {
    final selectedPrefecture = widget.selectedPrefecture;
    if (selectedPrefecture == null ||
        widget.controller.text == selectedPrefecture) {
      return;
    }
    _isApplyingSelection = true;
    widget.controller.text = selectedPrefecture;
    widget.controller.selection = TextSelection.collapsed(
      offset: selectedPrefecture.length,
    );
    _isApplyingSelection = false;
  }

  void _handleFocusChanged() {
    if (!mounted) {
      return;
    }

    if (_focusNode.hasFocus && widget.selectedPrefecture != null) {
      _isApplyingSelection = true;
      widget.controller.clear();
      _isApplyingSelection = false;
      widget.onSelected(null);
      setState(() {
        _filteredPrefectures = _prefectureOptions;
      });
      return;
    }

    setState(() {
      _filteredPrefectures = _filterPrefectures(widget.controller.text);
    });
  }

  void _handleTextChanged() {
    if (_isApplyingSelection) {
      return;
    }

    final text = widget.controller.text;
    if (widget.selectedPrefecture != null &&
        text != widget.selectedPrefecture) {
      widget.onSelected(null);
    }

    setState(() {
      _filteredPrefectures = _filterPrefectures(text);
    });
  }

  List<String> _filterPrefectures(String query) {
    final normalizedQuery = normalizeLocationText(query);
    if (normalizedQuery.isEmpty) {
      return _prefectureOptions;
    }
    return _prefectureOptions
        .where(
          (prefecture) => _prefectureSearchTargets(
            prefecture,
          ).any((target) => target.contains(normalizedQuery)),
        )
        .toList(growable: false);
  }

  Iterable<String> _prefectureSearchTargets(String prefecture) sync* {
    yield normalizeLocationText(prefecture);
    final kana = _prefectureKanaByName[prefecture];
    if (kana != null) {
      yield normalizeLocationText(kana);
    }
  }

  void _selectPrefecture(String prefecture) {
    _isApplyingSelection = true;
    widget.controller.text = prefecture;
    widget.controller.selection = TextSelection.collapsed(
      offset: prefecture.length,
    );
    _isApplyingSelection = false;
    widget.onSelected(prefecture);
    _focusNode.unfocus();
    setState(() {
      _filteredPrefectures = _filterPrefectures(prefecture);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasPanel = _focusNode.hasFocus && _filteredPrefectures.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          key: const ValueKey('prefecture-search-field'),
          controller: widget.controller,
          focusNode: _focusNode,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.map_outlined),
            suffixIcon: Icon(Icons.expand_more_rounded),
            hintText: '都道府県を選択',
          ),
          validator: (_) {
            if (widget.selectedPrefecture == null) {
              return '都道府県を選択してください';
            }
            return null;
          },
        ),
        AnimatedSwitcher(
          duration: AppMotion.medium,
          child: hasPanel
              ? Padding(
                  key: const ValueKey('prefecture-suggestion-panel'),
                  padding: const EdgeInsets.only(top: AppSpacing.small),
                  child: _SuggestionPanel(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _filteredPrefectures.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final prefecture = _filteredPrefectures[index];
                        return ListTile(
                          leading: const Icon(Icons.map_outlined),
                          title: Text(prefecture),
                          onTap: () => _selectPrefecture(prefecture),
                        );
                      },
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('empty-prefecture-panel')),
        ),
      ],
    );
  }
}

class _LocationSearchField extends StatefulWidget {
  const _LocationSearchField({
    required this.controller,
    required this.focusNode,
    required this.selectedPrefecture,
    required this.selectedLocation,
    required this.onSubmitted,
    required this.onSelected,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? selectedPrefecture;
  final LocationSuggestion? selectedLocation;
  final VoidCallback onSubmitted;
  final ValueChanged<LocationSuggestion?> onSelected;

  @override
  State<_LocationSearchField> createState() => _LocationSearchFieldState();
}

class _LocationSearchFieldState extends State<_LocationSearchField> {
  final _repository = LocationRepositoryProvider.instance;

  Timer? _debounceTimer;
  List<LocationSuggestion> _allSuggestions = const [];
  List<LocationSuggestion> _suggestions = const [];
  bool _isLoading = false;
  bool _hasFiltered = false;
  String? _errorMessage;
  int _requestSerial = 0;
  bool _isApplyingSelection = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChanged);
    widget.focusNode.addListener(_handleFocusChanged);
    final selectedPrefecture = widget.selectedPrefecture;
    if (selectedPrefecture != null) {
      _loadPrefectureCandidates(selectedPrefecture);
    }
  }

  @override
  void didUpdateWidget(covariant _LocationSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChanged);
      widget.focusNode.addListener(_handleFocusChanged);
    }
    if (oldWidget.selectedPrefecture != widget.selectedPrefecture) {
      _debounceTimer?.cancel();
      final selectedPrefecture = widget.selectedPrefecture;
      setState(() {
        _allSuggestions = const [];
        _suggestions = const [];
        _isLoading = selectedPrefecture != null;
        _hasFiltered = false;
        _errorMessage = null;
      });
      if (selectedPrefecture != null) {
        _loadPrefectureCandidates(selectedPrefecture);
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    widget.focusNode.removeListener(_handleFocusChanged);
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (!mounted || !widget.focusNode.hasFocus) {
      return;
    }
    if (widget.selectedPrefecture == null) {
      return;
    }

    _debounceTimer?.cancel();
    if (widget.selectedLocation != null) {
      _isApplyingSelection = true;
      widget.controller.clear();
      _isApplyingSelection = false;
      widget.onSelected(null);
    }

    setState(() {
      _suggestions = filterLocationSuggestions(
        _allSuggestions,
        widget.controller.text,
      );
      _hasFiltered = true;
      _errorMessage = null;
    });
  }

  void _handleTextChanged() {
    if (_isApplyingSelection) {
      return;
    }

    if (widget.selectedLocation != null) {
      widget.onSelected(null);
    }

    final query = widget.controller.text.trim();
    _debounceTimer?.cancel();

    if (query.isEmpty || widget.selectedPrefecture == null) {
      setState(() {
        _suggestions = widget.selectedPrefecture == null
            ? const []
            : filterLocationSuggestions(_allSuggestions, query);
        _hasFiltered =
            widget.selectedPrefecture != null && widget.focusNode.hasFocus;
        _errorMessage = null;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _filter(query);
    });
  }

  Future<void> _loadPrefectureCandidates(String prefecture) async {
    final requestSerial = ++_requestSerial;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final suggestions = await _repository.listLocationsByPrefecture(
        prefecture,
      );
      if (!mounted || requestSerial != _requestSerial) {
        return;
      }
      setState(() {
        _allSuggestions = suggestions;
        _suggestions = filterLocationSuggestions(
          suggestions,
          widget.controller.text,
        );
        _isLoading = false;
        _hasFiltered =
            widget.controller.text.trim().isNotEmpty ||
            (widget.focusNode.hasFocus && widget.selectedPrefecture != null);
      });
    } on LocationSearchException catch (error) {
      if (!mounted || requestSerial != _requestSerial) {
        return;
      }
      setState(() {
        _allSuggestions = const [];
        _suggestions = const [];
        _isLoading = false;
        _hasFiltered = true;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted || requestSerial != _requestSerial) {
        return;
      }
      setState(() {
        _allSuggestions = const [];
        _suggestions = const [];
        _isLoading = false;
        _hasFiltered = true;
        _errorMessage = '地点候補を取得できませんでした';
      });
    }
  }

  void _filter(String query) {
    if (!mounted) {
      return;
    }
    setState(() {
      _suggestions = filterLocationSuggestions(_allSuggestions, query);
      _hasFiltered = query.trim().isNotEmpty;
      _errorMessage = null;
    });
  }

  void _selectSuggestion(LocationSuggestion suggestion) {
    _debounceTimer?.cancel();
    _isApplyingSelection = true;
    widget.controller.text = suggestion.displayName;
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );
    _isApplyingSelection = false;
    widget.onSelected(suggestion);
    setState(() {
      _suggestions = const [];
      _isLoading = false;
      _hasFiltered = false;
      _errorMessage = null;
    });
    widget.focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final hasPanel =
        _isLoading ||
        _errorMessage != null ||
        _suggestions.isNotEmpty ||
        _hasFiltered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          key: const ValueKey('location-search-field'),
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.selectedPrefecture != null,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => widget.onSubmitted(),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.location_on_outlined),
            hintText: widget.selectedPrefecture == null
                ? '先に都道府県を選択'
                : '駅・市区町村を入力',
          ),
          validator: (value) {
            if (widget.selectedPrefecture == null) {
              return '先に都道府県を選択してください';
            }
            if (value == null || value.trim().isEmpty) {
              return '行きたいエリアを入力してください';
            }
            if (widget.selectedLocation == null) {
              return '候補から地点を選択してください';
            }
            return null;
          },
        ),
        AnimatedSwitcher(
          duration: AppMotion.medium,
          child: hasPanel
              ? Padding(
                  key: const ValueKey('location-suggestion-panel'),
                  padding: const EdgeInsets.only(top: AppSpacing.small),
                  child: _SuggestionPanel(child: _buildPanel(context)),
                )
              : const SizedBox.shrink(key: ValueKey('empty-location-panel')),
        ),
      ],
    );
  }

  Widget _buildPanel(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.medium),
        child: LinearProgressIndicator(),
      );
    }

    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Text(
          errorMessage,
          style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      final message = _allSuggestions.isEmpty
          ? 'この都道府県の地点候補が未投入です'
          : '候補が見つかりません';
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Text(
          message,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: _suggestions.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: colors.outlineVariant),
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        final isStation = suggestion.type == LocationSuggestionType.station;
        return ListTile(
          leading: Icon(isStation ? Icons.train_rounded : Icons.place_outlined),
          title: Row(
            children: [
              Expanded(child: Text(suggestion.name)),
              const SizedBox(width: AppSpacing.small),
              _LocationTypeBadge(label: isStation ? '駅' : '市区町村'),
            ],
          ),
          subtitle: Text(suggestion.supportingText),
          onTap: () => _selectSuggestion(suggestion),
        );
      },
    );
  }
}

class _SuggestionPanel extends StatelessWidget {
  const _SuggestionPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: child,
        ),
      ),
    );
  }
}

class _LocationTypeBadge extends StatelessWidget {
  const _LocationTypeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.small,
          vertical: AppSpacing.micro,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

class _BudgetChoiceChip extends StatefulWidget {
  const _BudgetChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  State<_BudgetChoiceChip> createState() => _BudgetChoiceChipState();
}

class _BudgetChoiceChipState extends State<_BudgetChoiceChip> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEmphasized = widget.selected || _isHovered || _isFocused;

    return Focus(
      onFocusChange: (value) => setState(() => _isFocused = value),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedScale(
          scale: isEmphasized ? 1.02 : 1,
          duration: AppMotion.quick,
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: AppMotion.medium,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.control),
              boxShadow: widget.selected
                  ? AppShadows.elevatedAction(colors.primary)
                  : const [],
            ),
            child: ChoiceChip(
              label: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.micro,
                  vertical: AppSpacing.small,
                ),
                child: Text(widget.label),
              ),
              selected: widget.selected,
              onSelected: widget.onSelected,
            ),
          ),
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.step,
    required this.title,
    required this.child,
  });

  final String step;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: AppSizes.touchTarget,
              height: AppSizes.touchTarget,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Text(
                step,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.regular),
            Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
          ],
        ),
        const SizedBox(height: AppSpacing.medium),
        child,
      ],
    );
  }
}

class _PeopleCounter extends StatelessWidget {
  const _PeopleCounter({
    required this.peopleCount,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int peopleCount;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: '人数を減らす',
            onPressed: onDecrease,
            style: IconButton.styleFrom(
              minimumSize: const Size.square(AppSizes.secondaryButtonHeight),
            ),
            icon: const Icon(Icons.remove_rounded),
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              label: '$peopleCount人',
              excludeSemantics: true,
              child: Text(
                '$peopleCount人',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
            ),
          ),
          IconButton.filled(
            tooltip: '人数を増やす',
            onPressed: onIncrease,
            style: IconButton.styleFrom(
              minimumSize: const Size.square(AppSizes.secondaryButtonHeight),
            ),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

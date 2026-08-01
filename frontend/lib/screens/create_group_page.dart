import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/group_creation_draft.dart';
import '../models/location_suggestion.dart';
import '../services/location_repository.dart';
import '../services/room_repository.dart';
import '../services/user_error_messages.dart';
import '../theme/app_tokens.dart';
import '../widgets/primary_action_button.dart';
import 'group_created_page.dart';
import 'waiting_room_page.dart';

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

const _prefectureRomanByName = <String, String>{
  '北海道': 'hokkaido',
  '青森県': 'aomori',
  '岩手県': 'iwate',
  '宮城県': 'miyagi',
  '秋田県': 'akita',
  '山形県': 'yamagata',
  '福島県': 'fukushima',
  '茨城県': 'ibaraki',
  '栃木県': 'tochigi',
  '群馬県': 'gunma',
  '埼玉県': 'saitama',
  '千葉県': 'chiba',
  '東京都': 'tokyo',
  '神奈川県': 'kanagawa',
  '新潟県': 'niigata',
  '富山県': 'toyama',
  '石川県': 'ishikawa',
  '福井県': 'fukui',
  '山梨県': 'yamanashi',
  '長野県': 'nagano',
  '岐阜県': 'gifu',
  '静岡県': 'shizuoka',
  '愛知県': 'aichi',
  '三重県': 'mie',
  '滋賀県': 'shiga',
  '京都府': 'kyoto',
  '大阪府': 'osaka',
  '兵庫県': 'hyogo',
  '奈良県': 'nara',
  '和歌山県': 'wakayama',
  '鳥取県': 'tottori',
  '島根県': 'shimane',
  '岡山県': 'okayama',
  '広島県': 'hiroshima',
  '山口県': 'yamaguchi',
  '徳島県': 'tokushima',
  '香川県': 'kagawa',
  '愛媛県': 'ehime',
  '高知県': 'kochi',
  '福岡県': 'fukuoka',
  '佐賀県': 'saga',
  '長崎県': 'nagasaki',
  '熊本県': 'kumamoto',
  '大分県': 'oita',
  '宮崎県': 'miyazaki',
  '鹿児島県': 'kagoshima',
  '沖縄県': 'okinawa',
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
  final _areaController = TextEditingController();
  final _areaFocusNode = FocusNode();

  String? _selectedPrefecture;
  LocationSuggestion? _selectedLocation;
  CustomLocationInput? _currentLocation;
  int _peopleCount = 4;
  BudgetOption? _selectedBudget = BudgetOption.from2000To3000;
  bool _hasTriedSubmit = false;
  bool _isSubmitting = false;
  bool _isReadingLocation = false;

  @override
  void dispose() {
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
        ..showSnackBar(
          const SnackBar(
            content: Text('エリアを入力するとグループを作成できます'),
            duration: Duration(milliseconds: 1800),
          ),
        );
      return;
    }

    final selectedBudget = _selectedBudget;
    if (selectedBudget == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('予算を選んでください'),
            duration: Duration(milliseconds: 1800),
          ),
        );
      return;
    }

    setState(() => _isSubmitting = true);
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final draft = await _roomRepository.createRoom(
        peopleCount: _peopleCount,
        area:
            _selectedLocation?.displayName ??
            _currentLocation?.displayName ??
            _areaController.text.trim(),
        budget: selectedBudget,
        locationId: _selectedLocation?.id,
        customLocation: _selectedLocation == null ? _currentLocation : null,
      );
      if (!mounted) {
        return;
      }
      final nextRoute =
          draft.restaurantSearchStatus == RestaurantSearchStatus.noResults
          ? GroupCreatedPage.routeName
          : WaitingRoomPage.routeName;
      await Navigator.of(context).pushNamed(nextRoute, arguments: draft);
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
      _currentLocation = null;
    });
  }

  void _selectPrefecture(String? prefecture) {
    setState(() {
      _selectedPrefecture = prefecture;
      _selectedLocation = null;
      _currentLocation = null;
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
          timeLimit: Duration(seconds: 12),
        ),
      );
      final locationName = await _readAreaName(position);
      final area = locationName.area ?? '現在地周辺';

      if (!mounted) {
        return;
      }
      final prefecture = locationName.prefecture ?? _normalizePrefecture(area);
      _areaController.clear();
      setState(() {
        _selectedPrefecture = null;
        _selectedLocation = null;
        _currentLocation = CustomLocationInput(
          displayName: area,
          prefectureName: prefecture,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy.isFinite ? position.accuracy : null,
        );
        _hasTriedSubmit = false;
      });
      _showLocationSnackBar('$area を現在地として入力しました');
    } on LocationServiceDisabledException {
      _showLocationSnackBar('位置情報サービスをオンにしてください');
    } on PermissionDeniedException {
      _showLocationSnackBar('位置情報の許可が必要です');
    } on TimeoutException {
      _showLocationSnackBar('位置情報の取得に時間がかかっています');
    } catch (_) {
      _showLocationSnackBar('位置情報を読み取れませんでした');
    } finally {
      if (mounted) {
        setState(() => _isReadingLocation = false);
      }
    }
  }

  Future<({String? area, String? prefecture})> _readAreaName(
    Position position,
  ) async {
    try {
      final placemarks = await Geocoding(
        locale: const Locale('ja', 'JP'),
      ).placemarkFromCoordinates(position.latitude, position.longitude);
      final placemark = placemarks.isEmpty ? null : placemarks.first;
      final area = _formatAreaFromPlacemark(placemark);
      final prefecture = _normalizePrefecture(placemark?.administrativeArea);
      if (area != null && prefecture != null) {
        return (area: area, prefecture: prefecture);
      }
      final fallback = await _readAreaNameFromOpenStreetMap(position);
      return (
        area: area ?? fallback.area,
        prefecture: prefecture ?? fallback.prefecture,
      );
    } catch (_) {
      // Flutter WebではOSの逆ジオコーディングが使えない環境があるため、
      // 公開APIで地名だけ補完する。
    }

    return _readAreaNameFromOpenStreetMap(position);
  }

  Future<({String? area, String? prefecture})> _readAreaNameFromOpenStreetMap(
    Position position,
  ) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': position.latitude.toString(),
        'lon': position.longitude.toString(),
        'zoom': '16',
        'addressdetails': '1',
        'accept-language': 'ja',
      });
      final response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return (area: null, prefecture: null);
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, Object?>) {
        return (area: null, prefecture: null);
      }
      final address = decoded['address'];
      if (address is! Map<String, Object?>) {
        return (area: null, prefecture: null);
      }

      final area = _firstFilled([
        address['city'] as String?,
        address['ward'] as String?,
        address['town'] as String?,
        address['suburb'] as String?,
        address['village'] as String?,
        address['municipality'] as String?,
        address['state'] as String?,
      ]);
      return (
        area: area,
        prefecture: _normalizePrefecture(address['state'] as String?),
      );
    } catch (_) {
      return (area: null, prefecture: null);
    }
  }

  String? _normalizePrefecture(String? value) {
    final rawPrefecture = value?.trim();
    if (rawPrefecture == null || rawPrefecture.isEmpty) {
      return null;
    }

    for (final prefecture in _prefectureOptions) {
      if (rawPrefecture == prefecture || rawPrefecture.contains(prefecture)) {
        return prefecture;
      }
    }

    final normalized = _normalizeRomanPrefectureText(
      rawPrefecture,
    ).replaceAll(RegExp('[^a-z]'), '');
    for (final entry in _prefectureRomanByName.entries) {
      final roman = entry.value;
      if (normalized == roman ||
          normalized == '${roman}prefecture' ||
          normalized == '${roman}pref' ||
          normalized == '${roman}ken' ||
          normalized == '${roman}fu' ||
          normalized == '${roman}to' ||
          normalized == '${roman}metropolis' ||
          normalized.startsWith(roman)) {
        return entry.key;
      }
    }

    return null;
  }

  String _normalizeRomanPrefectureText(String value) {
    return value
        .toLowerCase()
        .replaceAll('ā', 'a')
        .replaceAll('ī', 'i')
        .replaceAll('ū', 'u')
        .replaceAll('ē', 'e')
        .replaceAll('ō', 'o');
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
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1800),
        ),
      );
  }

  void _clearCurrentLocation() {
    if (_currentLocation == null) {
      return;
    }
    setState(() => _currentLocation = null);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
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
                        areaController: _areaController,
                        areaFocusNode: _areaFocusNode,
                        hasTriedSubmit: _hasTriedSubmit,
                        peopleCount: _peopleCount,
                        selectedPrefecture: _selectedPrefecture,
                        selectedLocation: _selectedLocation,
                        currentLocation: _currentLocation,
                        selectedBudget: _selectedBudget,
                        isReadingLocation: _isReadingLocation,
                        onPrefectureSelected: _selectPrefecture,
                        onLocationSelected: _selectLocation,
                        onCurrentLocationCleared: _clearCurrentLocation,
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
                  AnimatedSwitcher(
                    duration: AppMotion.medium,
                    child: isKeyboardVisible
                        ? const SizedBox.shrink(
                            key: ValueKey('hidden-create-group-action'),
                          )
                        : Column(
                            key: const ValueKey('visible-create-group-action'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: AppSpacing.regular),
                              SizedBox(
                                width: double.infinity,
                                child: PrimaryActionButton(
                                  label: 'グループを作成',
                                  onPressed: _isSubmitting
                                      ? null
                                      : _createGroup,
                                  isLoading: _isSubmitting,
                                  loadingLabel: '作成中',
                                ),
                              ),
                            ],
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
    required this.areaController,
    required this.areaFocusNode,
    required this.hasTriedSubmit,
    required this.peopleCount,
    required this.selectedPrefecture,
    required this.selectedLocation,
    required this.currentLocation,
    required this.selectedBudget,
    required this.isReadingLocation,
    required this.onPrefectureSelected,
    required this.onLocationSelected,
    required this.onCurrentLocationCleared,
    required this.onReadAreaFromLocation,
    required this.onDecreasePeople,
    required this.onIncreasePeople,
    required this.onBudgetSelected,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController areaController;
  final FocusNode areaFocusNode;
  final bool hasTriedSubmit;
  final int peopleCount;
  final String? selectedPrefecture;
  final LocationSuggestion? selectedLocation;
  final CustomLocationInput? currentLocation;
  final BudgetOption? selectedBudget;
  final bool isReadingLocation;
  final ValueChanged<String?> onPrefectureSelected;
  final ValueChanged<LocationSuggestion?> onLocationSelected;
  final VoidCallback onCurrentLocationCleared;
  final VoidCallback onReadAreaFromLocation;
  final VoidCallback? onDecreasePeople;
  final VoidCallback? onIncreasePeople;
  final ValueChanged<BudgetOption> onBudgetSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final currentLocation = this.currentLocation;

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
                  selectedPrefecture: selectedPrefecture,
                  hasCurrentLocation: currentLocation != null,
                  onSelected: onPrefectureSelected,
                ),
                const SizedBox(height: AppSpacing.regular),
                _LocationSearchField(
                  controller: areaController,
                  focusNode: areaFocusNode,
                  selectedPrefecture: selectedPrefecture,
                  selectedLocation: selectedLocation,
                  hasCurrentLocation: currentLocation != null,
                  onSelected: onLocationSelected,
                  onCurrentLocationCleared: onCurrentLocationCleared,
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
                if (currentLocation != null) ...[
                  const SizedBox(height: AppSpacing.regular),
                  _CurrentLocationPanel(
                    location: currentLocation,
                    onCleared: onCurrentLocationCleared,
                  ),
                ],
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
    required this.selectedPrefecture,
    required this.hasCurrentLocation,
    required this.onSelected,
  });

  final String? selectedPrefecture;
  final bool hasCurrentLocation;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : AppSizes.contentMaxWidth;

        return FormField<String>(
          key: ValueKey(
            'prefecture-select-form-$selectedPrefecture-$hasCurrentLocation',
          ),
          initialValue: selectedPrefecture,
          validator: (_) {
            if (hasCurrentLocation) {
              return null;
            }
            if (selectedPrefecture == null) {
              return '都道府県を選択してください';
            }
            return null;
          },
          builder: (field) {
            final theme = Theme.of(context);
            final colors = theme.colorScheme;

            return PopupMenuButton<String>(
              initialValue: selectedPrefecture,
              tooltip: '都道府県を選択',
              position: PopupMenuPosition.under,
              offset: const Offset(0, AppSpacing.micro),
              constraints: BoxConstraints(
                minWidth: fieldWidth,
                maxWidth: fieldWidth,
                maxHeight: 320,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              itemBuilder: (context) {
                return _prefectureOptions
                    .map((prefecture) {
                      final isSelected = prefecture == selectedPrefecture;
                      return PopupMenuItem<String>(
                        value: prefecture,
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_rounded
                                  : Icons.map_outlined,
                              color: isSelected ? colors.primary : null,
                            ),
                            const SizedBox(width: AppSpacing.regular),
                            Text(prefecture),
                          ],
                        ),
                      );
                    })
                    .toList(growable: false);
              },
              onSelected: (prefecture) {
                field.didChange(prefecture);
                onSelected(prefecture);
              },
              child: InputDecorator(
                key: const ValueKey('prefecture-select-field'),
                isEmpty: selectedPrefecture == null,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.map_outlined),
                  suffixIcon: const Icon(Icons.expand_more_rounded),
                  hintText: '都道府県を選択',
                  errorText: field.errorText,
                ),
                child: Text(
                  selectedPrefecture ?? '',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _LocationSearchField extends StatefulWidget {
  const _LocationSearchField({
    required this.controller,
    required this.focusNode,
    required this.selectedPrefecture,
    required this.selectedLocation,
    required this.hasCurrentLocation,
    required this.onSelected,
    required this.onCurrentLocationCleared,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? selectedPrefecture;
  final LocationSuggestion? selectedLocation;
  final bool hasCurrentLocation;
  final ValueChanged<LocationSuggestion?> onSelected;
  final VoidCallback onCurrentLocationCleared;

  @override
  State<_LocationSearchField> createState() => _LocationSearchFieldState();
}

class _LocationSearchFieldState extends State<_LocationSearchField> {
  Future<void> _openLocationSearch() async {
    final selectedPrefecture = widget.selectedPrefecture;
    if (selectedPrefecture == null) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    final selectedSuggestion = await showGeneralDialog<LocationSuggestion>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '地点検索を閉じる',
      barrierColor: Colors.transparent,
      transitionDuration: AppMotion.medium,
      pageBuilder: (context, _, _) {
        return _LocationSearchOverlay(
          prefecture: selectedPrefecture,
          initialQuery: widget.selectedLocation == null
              ? widget.controller.text
              : '',
        );
      },
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );

    if (!mounted || selectedSuggestion == null) {
      return;
    }

    widget.controller.text = selectedSuggestion.displayName;
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );
    widget.onCurrentLocationCleared();
    widget.onSelected(selectedSuggestion);
    widget.focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: const ValueKey('location-search-field'),
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.selectedPrefecture != null,
      readOnly: true,
      onTap: _openLocationSearch,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.location_on_outlined),
        suffixIcon: widget.selectedPrefecture == null
            ? null
            : const Icon(Icons.search_rounded),
        hintText: widget.selectedPrefecture == null ? '先に都道府県を選択' : '駅・市区町村を検索',
      ),
      validator: (value) {
        if (widget.hasCurrentLocation) {
          return null;
        }
        if (widget.selectedPrefecture == null && !widget.hasCurrentLocation) {
          return '先に都道府県を選択してください';
        }
        if (value == null || value.trim().isEmpty) {
          return '行きたいエリアを入力してください';
        }
        if (widget.selectedLocation == null && !widget.hasCurrentLocation) {
          return '候補から地点を選択してください';
        }
        return null;
      },
    );
  }
}

class _LocationSearchOverlay extends StatefulWidget {
  const _LocationSearchOverlay({
    required this.prefecture,
    required this.initialQuery,
  });

  final String prefecture;
  final String initialQuery;

  @override
  State<_LocationSearchOverlay> createState() => _LocationSearchOverlayState();
}

class _LocationSearchOverlayState extends State<_LocationSearchOverlay> {
  final _repository = LocationRepositoryProvider.instance;
  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  Timer? _debounceTimer;
  List<LocationSuggestion> _allSuggestions = const [];
  List<LocationSuggestion> _suggestions = const [];
  bool _isLoading = true;
  bool _hasFiltered = false;
  String? _errorMessage;
  int _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _controller.addListener(_handleTextChanged);
    _loadPrefectureCandidates();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _handleTextChanged() {
    final query = _controller.text.trim();
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _suggestions = filterLocationSuggestions(_allSuggestions, query);
        _hasFiltered = true;
        _errorMessage = null;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _filter(query);
    });
  }

  Future<void> _loadPrefectureCandidates() async {
    final requestSerial = ++_requestSerial;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final suggestions = await _repository.listLocationsByPrefecture(
        widget.prefecture,
      );
      if (!mounted || requestSerial != _requestSerial) {
        return;
      }
      setState(() {
        _allSuggestions = suggestions;
        _suggestions = filterLocationSuggestions(suggestions, _controller.text);
        _isLoading = false;
        _hasFiltered = true;
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
      _hasFiltered = true;
      _errorMessage = null;
    });
  }

  void _submitFirstSuggestion() {
    if (_suggestions.isNotEmpty) {
      Navigator.of(context).pop(_suggestions.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.regular,
                AppSpacing.regular,
                AppSpacing.regular,
                AppSpacing.small,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '閉じる',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('location-search-overlay-field'),
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _submitFirstSuggestion(),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _controller.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: '検索語を消す',
                                onPressed: _controller.clear,
                                icon: const Icon(Icons.close_rounded),
                              ),
                        hintText: '${widget.prefecture}の駅・市区町村',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.outlineVariant),
            if (_isLoading) const LinearProgressIndicator(),
            Expanded(child: _buildResults(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final errorMessage = _errorMessage;

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Text(
            errorMessage,
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.error),
          ),
        ),
      );
    }

    if (!_isLoading && _suggestions.isEmpty && _hasFiltered) {
      final message = _allSuggestions.isEmpty
          ? 'この都道府県の地点候補が未投入です'
          : '候補が見つかりません';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: AppSpacing.large),
      itemCount: _suggestions.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: colors.outlineVariant),
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        final isStation = suggestion.type == LocationSuggestionType.station;
        return ListTile(
          key: ValueKey(suggestion.id),
          leading: Icon(isStation ? Icons.train_rounded : Icons.place_outlined),
          title: Row(
            children: [
              Expanded(child: Text(suggestion.name)),
              const SizedBox(width: AppSpacing.small),
              _LocationTypeBadge(label: isStation ? '駅' : '市区町村'),
            ],
          ),
          subtitle: Text(suggestion.supportingText),
          onTap: () => Navigator.of(context).pop(suggestion),
        );
      },
    );
  }
}

class _CurrentLocationPanel extends StatelessWidget {
  const _CurrentLocationPanel({
    required this.location,
    required this.onCleared,
  });

  final CustomLocationInput location;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final prefectureName = location.prefectureName;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Row(
          children: [
            Icon(Icons.my_location_rounded, color: colors.onSecondaryContainer),
            const SizedBox(width: AppSpacing.regular),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '現在地',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.micro),
                  Text(
                    prefectureName == null
                        ? location.displayName
                        : '${location.displayName} / $prefectureName',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '現在地を解除',
              onPressed: onCleared,
              color: colors.onSecondaryContainer,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
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

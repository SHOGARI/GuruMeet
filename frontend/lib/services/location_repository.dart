import '../core/api_config.dart';
import '../models/location_suggestion.dart';
import 'api_client.dart';

abstract final class LocationRepositoryProvider {
  static final LocationRepository instance = ApiConfig.enableMocks
      ? const MockLocationRepository()
      : ApiLocationRepository(
          apiClient: ApiClient(baseUrl: ApiConfig.apiBaseUrl),
        );
}

abstract interface class LocationRepository {
  Future<List<LocationSuggestion>> searchLocations(
    String query, {
    String? prefecture,
    int limit = 20,
  });
}

class ApiLocationRepository implements LocationRepository {
  const ApiLocationRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<LocationSuggestion>> searchLocations(
    String query, {
    String? prefecture,
    int limit = 20,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return const [];
    }

    final queryParameters = <String, String>{
      'q': trimmedQuery,
      'limit': '$limit',
    };
    final trimmedPrefecture = prefecture?.trim();
    if (trimmedPrefecture != null && trimmedPrefecture.isNotEmpty) {
      queryParameters['prefecture'] = trimmedPrefecture;
    }

    final List<dynamic> body;
    try {
      body = await _apiClient.getJsonList(
        '/locations/search',
        queryParameters: queryParameters,
      );
    } on ApiException catch (error) {
      throw LocationSearchException(error.message);
    }

    return body
        .whereType<Map<String, Object?>>()
        .map(LocationSuggestion.fromJson)
        .toList(growable: false);
  }
}

class MockLocationRepository implements LocationRepository {
  const MockLocationRepository();

  static const _suggestions = <LocationSuggestion>[
    LocationSuggestion(
      id: 'station:1130101',
      type: LocationSuggestionType.station,
      name: '東京駅',
      displayName: '東京駅・東京都千代田区',
      prefecture: '東京都',
      municipality: '千代田区',
      latitude: 35.6812,
      longitude: 139.7671,
      lineName: 'JR山手線 / JR中央線 / 東京メトロ丸ノ内線',
    ),
    LocationSuggestion(
      id: 'station:1130208',
      type: LocationSuggestionType.station,
      name: '新宿駅',
      displayName: '新宿駅・東京都新宿区',
      prefecture: '東京都',
      municipality: '新宿区',
      latitude: 35.6896,
      longitude: 139.7006,
      lineName: 'JR山手線 / 小田急線 / 京王線',
    ),
    LocationSuggestion(
      id: 'municipality:13104',
      type: LocationSuggestionType.municipality,
      name: '新宿区',
      displayName: '東京都新宿区',
      prefecture: '東京都',
      municipality: '新宿区',
      latitude: 35.6938,
      longitude: 139.7034,
    ),
    LocationSuggestion(
      id: 'station:1132005',
      type: LocationSuggestionType.station,
      name: '北千住駅',
      displayName: '北千住駅・東京都足立区',
      prefecture: '東京都',
      municipality: '足立区',
      latitude: 35.7494,
      longitude: 139.805,
      lineName: 'JR常磐線 / 東京メトロ千代田線',
    ),
    LocationSuggestion(
      id: 'municipality:13121',
      type: LocationSuggestionType.municipality,
      name: '足立区',
      displayName: '東京都足立区',
      prefecture: '東京都',
      municipality: '足立区',
      latitude: 35.7757,
      longitude: 139.8048,
    ),
    LocationSuggestion(
      id: 'station:9950101',
      type: LocationSuggestionType.station,
      name: '高田駅',
      displayName: '高田駅・神奈川県横浜市港北区',
      prefecture: '神奈川県',
      municipality: '横浜市港北区',
      latitude: 35.549,
      longitude: 139.62,
      lineName: '横浜市営地下鉄グリーンライン',
    ),
    LocationSuggestion(
      id: 'station:1163401',
      type: LocationSuggestionType.station,
      name: '高田駅',
      displayName: '高田駅・奈良県大和高田市',
      prefecture: '奈良県',
      municipality: '大和高田市',
      latitude: 34.516,
      longitude: 135.742,
      lineName: 'JR和歌山線',
    ),
  ];

  @override
  Future<List<LocationSuggestion>> searchLocations(
    String query, {
    String? prefecture,
    int limit = 20,
  }) async {
    final normalizedQuery = _normalizeLocationText(query);
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    await Future<void>.delayed(const Duration(milliseconds: 120));

    final ranked =
        _suggestions
            .where(
              (suggestion) =>
                  _matches(suggestion, normalizedQuery) &&
                  _matchesPrefecture(suggestion, prefecture),
            )
            .toList()
          ..sort((left, right) {
            final leftRank = _matchRank(left, normalizedQuery);
            final rightRank = _matchRank(right, normalizedQuery);
            if (leftRank != rightRank) {
              return leftRank.compareTo(rightRank);
            }
            if (left.type != right.type) {
              return left.type == LocationSuggestionType.station ? -1 : 1;
            }
            return left.displayName.compareTo(right.displayName);
          });

    return ranked.take(limit).toList(growable: false);
  }

  bool _matches(LocationSuggestion suggestion, String normalizedQuery) {
    return _searchTargets(
      suggestion,
    ).any((target) => target.contains(normalizedQuery));
  }

  bool _matchesPrefecture(LocationSuggestion suggestion, String? prefecture) {
    final trimmedPrefecture = prefecture?.trim();
    return trimmedPrefecture == null ||
        trimmedPrefecture.isEmpty ||
        suggestion.prefecture == trimmedPrefecture;
  }

  int _matchRank(LocationSuggestion suggestion, String normalizedQuery) {
    final targets = _searchTargets(suggestion);
    if (targets.any((target) => target == normalizedQuery)) {
      return 0;
    }
    if (targets.any((target) => target.startsWith(normalizedQuery))) {
      return 1;
    }
    return 2;
  }

  Iterable<String> _searchTargets(LocationSuggestion suggestion) sync* {
    yield _normalizeLocationText(suggestion.name);
    yield _normalizeLocationText(suggestion.displayName);
    yield _normalizeLocationText(suggestion.prefecture);
    final municipality = suggestion.municipality;
    if (municipality != null) {
      yield _normalizeLocationText(municipality);
    }
    final lineName = suggestion.lineName;
    if (lineName != null) {
      yield _normalizeLocationText(lineName);
    }
  }
}

class LocationSearchException implements Exception {
  const LocationSearchException(this.message);

  final String message;
}

String _normalizeLocationText(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
}

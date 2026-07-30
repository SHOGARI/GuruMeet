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
  Future<List<LocationSuggestion>> listLocationsByPrefecture(String prefecture);
}

class ApiLocationRepository implements LocationRepository {
  const ApiLocationRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<LocationSuggestion>> listLocationsByPrefecture(
    String prefecture,
  ) async {
    final trimmedPrefecture = prefecture.trim();
    if (trimmedPrefecture.isEmpty) {
      return const [];
    }

    final queryParameters = <String, String>{'prefecture': trimmedPrefecture};

    final List<dynamic> body;
    try {
      body = await _apiClient.getJsonList(
        '/locations',
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
      kana: 'トウキョウ',
      displayName: '東京駅・東京都千代田区',
      prefecture: '東京都',
      municipality: '千代田区',
      lineName: 'JR山手線 / JR中央線 / 東京メトロ丸ノ内線',
    ),
    LocationSuggestion(
      id: 'station:1130208',
      type: LocationSuggestionType.station,
      name: '新宿駅',
      kana: 'シンジュク',
      displayName: '新宿駅・東京都新宿区',
      prefecture: '東京都',
      municipality: '新宿区',
      lineName: 'JR山手線 / 小田急線 / 京王線',
    ),
    LocationSuggestion(
      id: 'station:1130205',
      type: LocationSuggestionType.station,
      name: '渋谷駅',
      kana: 'シブヤ',
      displayName: '渋谷駅・東京都渋谷区',
      prefecture: '東京都',
      municipality: '渋谷区',
      lineName: 'JR山手線 / 東急東横線 / 東京メトロ半蔵門線',
    ),
    LocationSuggestion(
      id: 'station:1130220',
      type: LocationSuggestionType.station,
      name: '秋葉原駅',
      kana: 'アキハバラ',
      displayName: '秋葉原駅・東京都千代田区',
      prefecture: '東京都',
      municipality: '千代田区',
      lineName: 'JR山手線 / 東京メトロ日比谷線 / つくばエクスプレス',
    ),
    LocationSuggestion(
      id: 'municipality:13104',
      type: LocationSuggestionType.municipality,
      name: '新宿区',
      kana: 'シンジュクク',
      displayName: '東京都新宿区',
      prefecture: '東京都',
      municipality: '新宿区',
    ),
    LocationSuggestion(
      id: 'municipality:13113',
      type: LocationSuggestionType.municipality,
      name: '渋谷区',
      kana: 'シブヤク',
      displayName: '東京都渋谷区',
      prefecture: '東京都',
      municipality: '渋谷区',
    ),
    LocationSuggestion(
      id: 'station:1132005',
      type: LocationSuggestionType.station,
      name: '北千住駅',
      kana: 'キタセンジュ',
      displayName: '北千住駅・東京都足立区',
      prefecture: '東京都',
      municipality: '足立区',
      lineName: 'JR常磐線 / 東京メトロ千代田線',
    ),
    LocationSuggestion(
      id: 'municipality:13121',
      type: LocationSuggestionType.municipality,
      name: '足立区',
      kana: 'アダチク',
      displayName: '東京都足立区',
      prefecture: '東京都',
      municipality: '足立区',
    ),
    LocationSuggestion(
      id: 'station:9950101',
      type: LocationSuggestionType.station,
      name: '高田駅',
      kana: 'タカタ',
      displayName: '高田駅・神奈川県横浜市港北区',
      prefecture: '神奈川県',
      municipality: '横浜市港北区',
      lineName: '横浜市営地下鉄グリーンライン',
    ),
    LocationSuggestion(
      id: 'station:1163401',
      type: LocationSuggestionType.station,
      name: '高田駅',
      kana: 'タカダ',
      displayName: '高田駅・奈良県大和高田市',
      prefecture: '奈良県',
      municipality: '大和高田市',
      lineName: 'JR和歌山線',
    ),
  ];

  @override
  Future<List<LocationSuggestion>> listLocationsByPrefecture(
    String prefecture,
  ) async {
    final trimmedPrefecture = prefecture.trim();
    if (trimmedPrefecture.isEmpty) {
      return const [];
    }

    await Future<void>.delayed(const Duration(milliseconds: 120));

    return _suggestions
        .where((suggestion) => suggestion.prefecture == trimmedPrefecture)
        .toList(growable: false);
  }
}

List<LocationSuggestion> filterLocationSuggestions(
  List<LocationSuggestion> suggestions,
  String query, {
  int limit = 20,
}) {
  final normalizedQuery = normalizeLocationText(query);
  if (normalizedQuery.isEmpty) {
    return sortLocationSuggestions(suggestions);
  }

  final ranked = suggestions
      .where((suggestion) => _matches(suggestion, normalizedQuery))
      .toList(growable: false);
  ranked.sort((left, right) {
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

List<LocationSuggestion> sortLocationSuggestions(
  List<LocationSuggestion> suggestions,
) {
  final sorted = suggestions.toList(growable: false);
  sorted.sort((left, right) {
    final leftKey = _sortKey(left);
    final rightKey = _sortKey(right);
    final keyOrder = leftKey.compareTo(rightKey);
    if (keyOrder != 0) {
      return keyOrder;
    }
    return left.displayName.compareTo(right.displayName);
  });
  return sorted;
}

String _sortKey(LocationSuggestion suggestion) {
  final kana = suggestion.kana;
  if (kana != null && kana.trim().isNotEmpty) {
    return normalizeLocationText(kana);
  }
  return normalizeLocationText(suggestion.name);
}

bool _matches(LocationSuggestion suggestion, String normalizedQuery) {
  return _searchTargets(
    suggestion,
  ).any((target) => target.contains(normalizedQuery));
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
  yield normalizeLocationText(suggestion.name);
  final kana = suggestion.kana;
  if (kana != null) {
    yield normalizeLocationText(kana);
  }
  yield normalizeLocationText(suggestion.displayName);
  yield normalizeLocationText(suggestion.prefecture);
  final municipality = suggestion.municipality;
  if (municipality != null) {
    yield normalizeLocationText(municipality);
  }
  final lineName = suggestion.lineName;
  if (lineName != null) {
    yield normalizeLocationText(lineName);
  }
}

class LocationSearchException implements Exception {
  const LocationSearchException(this.message);

  final String message;
}

String normalizeLocationText(String value) {
  final buffer = StringBuffer();
  for (final rune in value.trim().toLowerCase().runes) {
    if (_isWhitespace(rune)) {
      continue;
    }
    if (rune >= 0xff01 && rune <= 0xff5e) {
      buffer.writeCharCode(rune - 0xfee0);
      continue;
    }
    if (rune >= 0x30a1 && rune <= 0x30f6) {
      buffer.writeCharCode(rune - 0x60);
      continue;
    }
    buffer.writeCharCode(rune);
  }
  return buffer.toString();
}

bool _isWhitespace(int rune) {
  return rune == 0x20 ||
      rune == 0x3000 ||
      rune == 0x09 ||
      rune == 0x0a ||
      rune == 0x0d;
}

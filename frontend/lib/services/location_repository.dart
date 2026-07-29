import '../core/api_config.dart';
import '../models/location_suggestion.dart';
import 'api_client.dart';

abstract final class LocationRepositoryProvider {
  static final LocationRepository instance = LocationRepository(
    apiClient: ApiClient(baseUrl: ApiConfig.apiBaseUrl),
  );
}

class LocationRepository {
  const LocationRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<LocationSuggestion>> searchLocations(
    String query, {
    int limit = 20,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return const [];
    }

    final List<dynamic> body;
    try {
      body = await _apiClient.getJsonList(
        '/locations/search',
        queryParameters: {'q': trimmedQuery, 'limit': '$limit'},
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

class LocationSearchException implements Exception {
  const LocationSearchException(this.message);

  final String message;
}

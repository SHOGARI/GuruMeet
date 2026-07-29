enum LocationSuggestionType {
  municipality,
  station;

  static LocationSuggestionType fromJson(String value) {
    return switch (value) {
      'station' => LocationSuggestionType.station,
      _ => LocationSuggestionType.municipality,
    };
  }
}

class LocationSuggestion {
  const LocationSuggestion({
    required this.id,
    required this.type,
    required this.name,
    required this.displayName,
    required this.prefecture,
    required this.latitude,
    required this.longitude,
    this.municipality,
    this.lineName,
  });

  factory LocationSuggestion.fromJson(Map<String, Object?> json) {
    return LocationSuggestion(
      id: json['id'] as String,
      type: LocationSuggestionType.fromJson(json['type'] as String),
      name: json['name'] as String,
      displayName: json['displayName'] as String,
      prefecture: json['prefecture'] as String,
      municipality: json['municipality'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      lineName: json['lineName'] as String?,
    );
  }

  final String id;
  final LocationSuggestionType type;
  final String name;
  final String displayName;
  final String prefecture;
  final String? municipality;
  final double latitude;
  final double longitude;
  final String? lineName;

  String get supportingText {
    final area = municipality == null ? prefecture : '$prefecture$municipality';
    if (lineName == null || lineName!.isEmpty) {
      return area;
    }
    return '$area・$lineName';
  }
}

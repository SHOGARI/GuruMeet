import 'dart:async';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_config.dart';
import '../core/demo_config.dart';
import '../models/group_creation_draft.dart';
import '../models/restaurant_preview.dart';
import '../models/room_member.dart';
import 'api_client.dart';
import 'mock_room_service.dart';
import 'participant_token_cookie_stub.dart'
    if (dart.library.html) 'participant_token_cookie_web.dart';

class VoteChoice {
  const VoteChoice({required this.restaurantId, required this.liked});

  final String restaurantId;
  final bool liked;
}

class VotingStatus {
  const VotingStatus({required this.members});

  final List<RoomMember> members;

  int get completedCount =>
      members.where((member) => member.hasCompletedVoting).length;
  bool get isComplete => members.isNotEmpty && completedCount == members.length;
}

class CustomLocationInput {
  const CustomLocationInput({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.prefectureName,
    this.accuracyMeters,
    this.source = 'current_location',
  });

  final String displayName;
  final String? prefectureName;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final String source;

  Map<String, Object?> toJson() {
    return {
      'displayName': displayName,
      'prefectureName': prefectureName,
      'latitude': latitude,
      'longitude': longitude,
      'accuracyMeters': accuracyMeters,
      'source': source,
    };
  }
}

class RoomInvitePreview {
  const RoomInvitePreview({
    required this.roomId,
    required this.code,
    required this.peopleCount,
    required this.joinedCount,
    required this.area,
    required this.budget,
    required this.isFull,
  });

  final String roomId;
  final String code;
  final int peopleCount;
  final int joinedCount;
  final String area;
  final BudgetOption budget;
  final bool isFull;
}

abstract class RoomRepository {
  Future<GroupCreationDraft> createRoom({
    required int peopleCount,
    required String area,
    required BudgetOption budget,
    String? locationId,
    CustomLocationInput? customLocation,
  });

  Future<GroupCreationDraft> joinRoom({required String code});

  Future<RoomInvitePreview> getInvitePreview({required String inviteToken});

  Future<void> dissolveRoom(GroupCreationDraft draft);

  Future<List<RoomMember>> getMembers(GroupCreationDraft draft);

  Future<void> startVoting(GroupCreationDraft draft);

  Future<bool> isVotingStarted(GroupCreationDraft draft);

  Future<List<RestaurantPreview>> getRestaurantCandidates(
    GroupCreationDraft draft,
  );

  Future<void> submitVote({
    required GroupCreationDraft draft,
    required VoteChoice choice,
  });

  Future<VotingStatus> getVotingStatus(GroupCreationDraft draft);

  Future<RestaurantMatchResult> getResult({
    required GroupCreationDraft draft,
    required List<RestaurantPreview> restaurants,
    required List<VoteChoice> localChoices,
  });
}

abstract final class RoomRepositoryProvider {
  static final RoomRepository instance = ApiConfig.enableMocks
      ? MockRoomRepository()
      : ApiRoomRepository(
          apiClient: ApiClient(baseUrl: ApiConfig.apiBaseUrl),
          fallback: MockRoomRepository(),
        );
}

class MockRoomRepository implements RoomRepository {
  MockRoomRepository();

  final MockRoomService _mockRoomService = const MockRoomService();
  final Map<String, int> _statusPollCounts = {};

  @override
  Future<GroupCreationDraft> createRoom({
    required int peopleCount,
    required String area,
    required BudgetOption budget,
    String? locationId,
    CustomLocationInput? customLocation,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return GroupCreationDraft.createMock(
      peopleCount: peopleCount,
      area: area,
      budget: budget,
      locationId: locationId,
    );
  }

  @override
  Future<GroupCreationDraft> joinRoom({required String code}) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return GroupCreationDraft.joinMock(groupId: code);
  }

  @override
  Future<RoomInvitePreview> getInvitePreview({
    required String inviteToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return RoomInvitePreview(
      roomId: inviteToken,
      code: inviteToken.length == 5
          ? inviteToken.toUpperCase()
          : DemoConfig.roomCode,
      peopleCount: 4,
      joinedCount: 1,
      area: '新宿',
      budget: BudgetOption.from2000To3000,
      isFull: false,
    );
  }

  @override
  Future<void> dissolveRoom(GroupCreationDraft draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  @override
  Future<List<RoomMember>> getMembers(GroupCreationDraft draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final currentCount = (_statusPollCounts[draft.groupId] ?? 0) + 1;
    _statusPollCounts[draft.groupId] = currentCount;
    final joinedCount = currentCount.clamp(1, draft.peopleCount);
    return _demoMembers(
      joinedCount: joinedCount,
      peopleCount: draft.peopleCount,
      completedVotingCount: 0,
    );
  }

  @override
  Future<void> startVoting(GroupCreationDraft draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
  }

  @override
  Future<bool> isVotingStarted(GroupCreationDraft draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return false;
  }

  @override
  Future<List<RestaurantPreview>> getRestaurantCandidates(
    GroupCreationDraft draft,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    return mockRestaurants;
  }

  @override
  Future<void> submitVote({
    required GroupCreationDraft draft,
    required VoteChoice choice,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 90));
  }

  @override
  Future<VotingStatus> getVotingStatus(GroupCreationDraft draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final key = 'voting-${draft.groupId}';
    final currentCount = (_statusPollCounts[key] ?? 0) + 1;
    _statusPollCounts[key] = currentCount;
    final completedVotingCount = currentCount.clamp(1, draft.peopleCount);
    return VotingStatus(
      members: _demoMembers(
        joinedCount: draft.peopleCount,
        peopleCount: draft.peopleCount,
        completedVotingCount: completedVotingCount,
      ),
    );
  }

  @override
  Future<RestaurantMatchResult> getResult({
    required GroupCreationDraft draft,
    required List<RestaurantPreview> restaurants,
    required List<VoteChoice> localChoices,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final targets = restaurants.isEmpty ? mockRestaurants : restaurants;
    final results = <RestaurantVoteResult>[];
    for (var index = 0; index < targets.length; index++) {
      final restaurant = targets[index];
      final likeCount = switch (index) {
        0 => draft.peopleCount,
        1 => (draft.peopleCount - 1).clamp(0, draft.peopleCount),
        2 => (draft.peopleCount - 2).clamp(0, draft.peopleCount),
        _ => (draft.peopleCount - 3).clamp(0, draft.peopleCount),
      };
      results.add(
        RestaurantVoteResult(
          restaurant: restaurant,
          likeCount: likeCount,
          rejectCount: draft.peopleCount - likeCount,
        ),
      );
    }

    return RestaurantMatchResult(
      restaurant: targets.first,
      results: results,
      peopleCount: draft.peopleCount,
    );
  }

  List<RoomMember> _demoMembers({
    required int joinedCount,
    required int peopleCount,
    required int completedVotingCount,
  }) {
    final members = _mockRoomService
        .initialVotingMembers(peopleCount: peopleCount)
        .take(joinedCount)
        .toList();
    return [
      for (var index = 0; index < members.length; index++)
        members[index].copyWith(
          isReady: true,
          hasCompletedVoting: index < completedVotingCount,
        ),
    ];
  }
}

class ApiRoomRepository implements RoomRepository {
  ApiRoomRepository({
    required ApiClient apiClient,
    required RoomRepository fallback,
  }) : _apiClient = apiClient,
       _fallback = fallback;

  final ApiClient _apiClient;
  final RoomRepository _fallback;
  Future<String>? _participantTokenFuture;
  static const _participantTokenStorageKey = 'gurumeet_participant_token';

  @override
  Future<GroupCreationDraft> createRoom({
    required int peopleCount,
    required String area,
    required BudgetOption budget,
    String? locationId,
    CustomLocationInput? customLocation,
  }) async {
    final participantToken = await _participantToken();
    final body = <String, Object?>{
      'participant_token': participantToken,
      'participant_count': peopleCount,
      'location': area,
      'budget_min': budget.minAmount,
      'budget_max': budget.maxAmount,
    };
    if (locationId != null) {
      body['location_id'] = locationId;
    }
    if (customLocation != null) {
      body['custom_location'] = customLocation.toJson();
    }

    final json = await _apiClient.postJson('/temporary-groups', body: body);
    return GroupCreationDraft.fromApi(
      roomId: json['id'] as String,
      groupId: json['code'] as String,
      peopleCount: peopleCount,
      area: area,
      budget: budget,
      isHost: true,
      locationId: locationId,
      phase: GroupPhase.fromApi(json['phase']),
      restaurantSearchStatus: RestaurantSearchStatus.fromApi(
        json['restaurant_search_status'],
      ),
    );
  }

  @override
  Future<GroupCreationDraft> joinRoom({required String code}) async {
    final inviteToken = code.trim();
    final participantToken = await _participantToken();
    final json = _isUuid(inviteToken)
        ? await _apiClient.postJson(
            '/temporary-groups/$inviteToken/participants',
            body: {'participant_token': participantToken},
          )
        : await _apiClient.postJson(
            '/temporary-groups/join',
            body: {
              'code': inviteToken.toUpperCase(),
              'participant_token': participantToken,
            },
          );
    final roomId = json['id'] as String;
    final detail = await _apiClient.getJson('/temporary-groups/$roomId');
    return GroupCreationDraft.fromApi(
      roomId: roomId,
      groupId: json['code'] as String,
      peopleCount: detail['participant_count'] as int? ?? 4,
      area: detail['location'] as String? ?? 'エリア未設定',
      budget: BudgetOption.fromRange(
        minAmount: detail['budget_min'] as int?,
        maxAmount: detail['budget_max'] as int?,
      ),
      isHost: false,
      locationId: detail['location_id'] as String?,
      phase: GroupPhase.fromApi(detail['phase'] ?? json['phase']),
      restaurantSearchStatus: RestaurantSearchStatus.fromApi(
        detail['restaurant_search_status'],
      ),
    );
  }

  bool _isUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  @override
  Future<void> dissolveRoom(GroupCreationDraft draft) async {
    final roomId = draft.roomId;
    if (roomId == null) {
      return _fallback.dissolveRoom(draft);
    }
    final participantToken = await _participantToken();
    await _apiClient.postJson(
      '/temporary-groups/$roomId/dissolve',
      body: {'participant_token': participantToken},
    );
  }

  @override
  Future<RoomInvitePreview> getInvitePreview({
    required String inviteToken,
  }) async {
    final token = inviteToken.trim();
    if (!_isUuid(token)) {
      throw const ApiException('招待リンクの形式が不正です');
    }
    final detail = await _apiClient.getJson('/temporary-groups/$token');
    return _previewFromDetail(detail);
  }

  @override
  Future<List<RoomMember>> getMembers(GroupCreationDraft draft) async {
    final roomId = draft.roomId;
    if (roomId == null) {
      return _fallback.getMembers(draft);
    }
    final participantToken = await _participantToken();
    final json = await _apiClient.getJson(
      '/temporary-groups/$roomId/voting/progress',
      queryParameters: {'participant_token': participantToken},
    );
    final participants = json['participants'];
    if (participants is List && participants.isNotEmpty) {
      return _membersFromProgress(
        participants.whereType<Map<String, dynamic>>().toList(),
      );
    }
    final joinedCount =
        json['joined_participant_count'] as int? ?? draft.peopleCount;
    return _membersFromCount(
      joinedCount: joinedCount,
      peopleCount: draft.peopleCount,
      completedVotingCount: 0,
    );
  }

  @override
  Future<void> startVoting(GroupCreationDraft draft) async {
    final roomId = draft.roomId;
    if (roomId == null) {
      return _fallback.startVoting(draft);
    }
    final participantToken = await _participantToken();
    await _apiClient.postJson(
      '/temporary-groups/$roomId/voting/start',
      body: {'participant_token': participantToken},
    );
  }

  @override
  Future<bool> isVotingStarted(GroupCreationDraft draft) async {
    final roomId = draft.roomId;
    if (roomId == null) {
      return _fallback.isVotingStarted(draft);
    }
    final json = await _apiClient.getJson('/temporary-groups/$roomId');
    return json['voting_started_at'] != null;
  }

  @override
  Future<List<RestaurantPreview>> getRestaurantCandidates(
    GroupCreationDraft draft,
  ) async {
    final roomId = draft.roomId;
    if (roomId == null) {
      return _fallback.getRestaurantCandidates(draft);
    }
    final json = await _apiClient.getJson('/temporary-groups/$roomId');
    final restaurantPayload = json['restaurant'];
    if (restaurantPayload == null) {
      throw const ApiException('店舗候補がまだ取得されていません');
    }
    if (restaurantPayload is! Map<String, dynamic>) {
      throw const ApiException('店舗候補のレスポンス形式が不正です');
    }
    final restaurants = restaurantPayload['restaurants'];
    if (restaurants is! List) {
      throw const ApiException('店舗候補のレスポンス形式が不正です');
    }
    return restaurants
        .whereType<Map<String, dynamic>>()
        .map(_restaurantFromJson)
        .toList();
  }

  @override
  Future<void> submitVote({
    required GroupCreationDraft draft,
    required VoteChoice choice,
  }) async {
    final roomId = draft.roomId;
    if (roomId == null) {
      return _fallback.submitVote(draft: draft, choice: choice);
    }
    final participantToken = await _participantToken();
    await _apiClient.postJson(
      '/temporary-groups/$roomId/votes',
      body: {
        'participant_token': participantToken,
        'restaurant_id': choice.restaurantId,
        'liked': choice.liked,
      },
    );
  }

  @override
  Future<VotingStatus> getVotingStatus(GroupCreationDraft draft) async {
    final roomId = draft.roomId;
    if (roomId == null) {
      return _fallback.getVotingStatus(draft);
    }
    final participantToken = await _participantToken();
    final json = await _apiClient.getJson(
      '/temporary-groups/$roomId/voting/progress',
      queryParameters: {'participant_token': participantToken},
    );
    final participants = json['participants'];
    if (participants is List && participants.isNotEmpty) {
      return VotingStatus(
        members: _membersFromProgress(
          participants.whereType<Map<String, dynamic>>().toList(),
        ),
      );
    }
    final joinedCount =
        json['joined_participant_count'] as int? ?? draft.peopleCount;
    final completedCount = json['completed_participant_count'] as int? ?? 0;
    return VotingStatus(
      members: _membersFromCount(
        joinedCount: joinedCount,
        peopleCount: draft.peopleCount,
        completedVotingCount: completedCount,
      ),
    );
  }

  @override
  Future<RestaurantMatchResult> getResult({
    required GroupCreationDraft draft,
    required List<RestaurantPreview> restaurants,
    required List<VoteChoice> localChoices,
  }) async {
    final roomId = draft.roomId;
    if (roomId == null) {
      return _buildResult(
        draft: draft,
        restaurants: restaurants,
        localChoices: localChoices,
      );
    }
    final json = await _apiClient.getJson(
      '/temporary-groups/$roomId/voting/result',
    );
    final resultItems = json['results'];
    if (resultItems is! List) {
      throw const ApiException('投票結果のレスポンス形式が不正です');
    }
    final voteResults = resultItems.whereType<Map<String, dynamic>>().map((
      item,
    ) {
      final restaurantJson = item['restaurant'];
      if (restaurantJson is! Map<String, dynamic>) {
        throw const ApiException('投票結果の店舗形式が不正です');
      }
      return RestaurantVoteResult(
        restaurant: _restaurantFromJson(restaurantJson),
        likeCount: item['like_count'] as int? ?? 0,
        rejectCount: item['reject_count'] as int? ?? 0,
      );
    }).toList();
    final winner = voteResults.isEmpty
        ? (restaurants.isEmpty ? mockRestaurants.first : restaurants.first)
        : voteResults.first.restaurant;
    return RestaurantMatchResult(
      restaurant: winner,
      results: voteResults,
      peopleCount: draft.peopleCount,
    );
  }

  RestaurantPreview _restaurantFromJson(Map<String, dynamic> json) {
    final access = json['access'] as String? ?? '';
    final imageUrls = _imageUrlsFromJson(json);
    return RestaurantPreview(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '名称未設定',
      area: access.isEmpty ? '周辺エリア' : access,
      budget: json['budget'] as String? ?? '予算未設定',
      cuisine: json['genre'] as String? ?? 'ジャンル未設定',
      description: access.isEmpty ? '店舗詳細を確認してください。' : access,
      imageUrls: imageUrls,
      address: json['address'] as String? ?? '住所未設定',
    );
  }

  List<String> _imageUrlsFromJson(Map<String, dynamic> json) {
    final values = <Object?>[
      json['image_url'],
      json['imageUrl'],
      json['image'],
      json['photo_url'],
      json['photoUrl'],
      json['thumbnail_url'],
      json['thumbnailUrl'],
    ];

    final collection =
        json['image_urls'] ?? json['imageUrls'] ?? json['images'];
    if (collection is List) {
      values.addAll(collection);
    }

    final photo = json['photo'];
    if (photo is Map<String, dynamic>) {
      values.add(_nestedImageValue(photo, const ['pc', 'l']));
      values.add(_nestedImageValue(photo, const ['pc', 'm']));
      values.add(_nestedImageValue(photo, const ['mobile', 'l']));
    }

    final seen = <String>{};
    final urls = <String>[];
    for (final value in values) {
      final normalized = _normalizeImageUrl(value);
      if (normalized == null || seen.contains(normalized)) {
        continue;
      }
      seen.add(normalized);
      urls.add(normalized);
    }
    return urls;
  }

  Object? _nestedImageValue(Map<String, dynamic> json, List<String> path) {
    Object? current = json;
    for (final key in path) {
      if (current is! Map<String, dynamic>) {
        return null;
      }
      current = current[key];
    }
    return current;
  }

  String? _normalizeImageUrl(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final withScheme = trimmed.startsWith('//') ? 'https:$trimmed' : trimmed;
    final uri = Uri.tryParse(withScheme);
    if (uri == null || !uri.hasScheme) {
      return null;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }
    if (uri.scheme == 'http') {
      return uri.replace(scheme: 'https').toString();
    }
    return uri.toString();
  }

  List<RoomMember> _membersFromCount({
    required int joinedCount,
    required int peopleCount,
    required int completedVotingCount,
  }) {
    final count = joinedCount.clamp(0, peopleCount);
    return List.generate(count, (index) {
      return RoomMember(
        id: index == 0 ? 'host' : 'member-$index',
        name: '参加者 ${index + 1}',
        avatarUrl: null,
        isHost: index == 0,
        isMe: index == 0,
        isReady: true,
        hasCompletedVoting: index < completedVotingCount,
      );
    });
  }

  List<RoomMember> _membersFromProgress(
    List<Map<String, dynamic>> participants,
  ) {
    return [
      for (var index = 0; index < participants.length; index++)
        RoomMember(
          id:
              participants[index]['anonymous_user_id'] as String? ??
              'member-$index',
          name: '参加者 ${index + 1}',
          avatarUrl: null,
          isHost: participants[index]['is_host'] == true,
          isMe: participants[index]['is_me'] == true,
          isReady: true,
          hasCompletedVoting: participants[index]['is_complete'] == true,
        ),
    ];
  }

  Future<String> _participantToken() {
    return _participantTokenFuture ??= _loadOrCreateParticipantToken();
  }

  RoomInvitePreview _previewFromDetail(Map<String, dynamic> json) {
    final peopleCount = json['participant_count'] as int? ?? 4;
    final joinedCount = json['joined_participant_count'] as int? ?? 0;
    return RoomInvitePreview(
      roomId: json['id'] as String? ?? '',
      code: (json['code'] as String? ?? '').toUpperCase(),
      peopleCount: peopleCount,
      joinedCount: joinedCount,
      area: json['location'] as String? ?? 'エリア未設定',
      budget: BudgetOption.fromRange(
        minAmount: json['budget_min'] as int?,
        maxAmount: json['budget_max'] as int?,
      ),
      isFull: joinedCount >= peopleCount,
    );
  }

  Future<String> _loadOrCreateParticipantToken() async {
    final preferences = await SharedPreferences.getInstance();
    final localStorageToken = _validParticipantToken(
      readParticipantTokenLocalStorage(),
    );
    final cookieToken = _validParticipantToken(readParticipantTokenCookie());
    final storedToken = _validParticipantToken(
      preferences.getString(_participantTokenStorageKey),
    );

    if (localStorageToken != null) {
      await preferences.setString(
        _participantTokenStorageKey,
        localStorageToken,
      );
      if (cookieToken != localStorageToken) {
        writeParticipantTokenCookie(localStorageToken);
      }
      return localStorageToken;
    }
    if (cookieToken != null) {
      await preferences.setString(_participantTokenStorageKey, cookieToken);
      writeParticipantTokenLocalStorage(cookieToken);
      return cookieToken;
    }
    if (storedToken != null) {
      writeParticipantTokenLocalStorage(storedToken);
      writeParticipantTokenCookie(storedToken);
      return storedToken;
    }

    final token = _newParticipantToken();
    await preferences.setString(_participantTokenStorageKey, token);
    writeParticipantTokenLocalStorage(token);
    writeParticipantTokenCookie(token);
    return token;
  }

  static String? _validParticipantToken(String? token) {
    final trimmed = token?.trim();
    if (trimmed == null || trimmed.length < 16 || trimmed.length > 256) {
      return null;
    }
    return trimmed;
  }

  static String _newParticipantToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return [
      hex.substring(0, 8),
      hex.substring(8, 12),
      hex.substring(12, 16),
      hex.substring(16, 20),
      hex.substring(20),
    ].join('-');
  }
}

RestaurantMatchResult _buildResult({
  required GroupCreationDraft draft,
  required List<RestaurantPreview> restaurants,
  required List<VoteChoice> localChoices,
}) {
  final choicesByRestaurant = {
    for (final choice in localChoices) choice.restaurantId: choice.liked,
  };
  final otherPeopleCount = (draft.peopleCount - 1).clamp(0, 99);
  final results = <RestaurantVoteResult>[];
  RestaurantVoteResult? matchedResult;
  var highestLikeCount = -1;

  for (var index = 0; index < restaurants.length; index++) {
    final restaurant = restaurants[index];
    final yourLikeCount = choicesByRestaurant[restaurant.id] ?? false ? 1 : 0;
    var otherLikeCount = 0;
    for (var person = 0; person < otherPeopleCount; person++) {
      final likes = (person + index + draft.groupId.codeUnitAt(0)) % 3 != 0;
      if (likes) {
        otherLikeCount++;
      }
    }
    final likeCount = yourLikeCount + otherLikeCount;
    final rejectCount = draft.peopleCount - likeCount;
    final result = RestaurantVoteResult(
      restaurant: restaurant,
      likeCount: likeCount,
      rejectCount: rejectCount,
    );
    results.add(result);
    if (likeCount > highestLikeCount) {
      highestLikeCount = likeCount;
      matchedResult = result;
    }
  }

  final fallback = restaurants.isEmpty
      ? mockRestaurants.first
      : restaurants.first;
  return RestaurantMatchResult(
    restaurant: matchedResult?.restaurant ?? fallback,
    results: results,
    peopleCount: draft.peopleCount,
  );
}

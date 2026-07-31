class RoomMember {
  const RoomMember({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.isHost,
    required this.isMe,
    required this.isReady,
    required this.hasCompletedVoting,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final bool isHost;
  final bool isMe;
  final bool isReady;
  final bool hasCompletedVoting;

  RoomMember copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    bool? isHost,
    bool? isMe,
    bool? isReady,
    bool? hasCompletedVoting,
  }) {
    return RoomMember(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isHost: isHost ?? this.isHost,
      isMe: isMe ?? this.isMe,
      isReady: isReady ?? this.isReady,
      hasCompletedVoting: hasCompletedVoting ?? this.hasCompletedVoting,
    );
  }
}

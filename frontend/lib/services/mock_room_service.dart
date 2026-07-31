import '../models/room_member.dart';

class MockRoomService {
  const MockRoomService();

  List<RoomMember> initialWaitingMembers({required int peopleCount}) {
    return _demoMembers(peopleCount)
        .map(
          (member) => member.copyWith(
            isReady: member.isHost,
            hasCompletedVoting: false,
          ),
        )
        .take(1)
        .toList();
  }

  RoomMember? nextWaitingMember({
    required List<RoomMember> currentMembers,
    required int peopleCount,
  }) {
    if (currentMembers.length >= peopleCount) {
      return null;
    }
    return _demoMembers(
      peopleCount,
    )[currentMembers.length].copyWith(isReady: true, hasCompletedVoting: false);
  }

  List<RoomMember> initialVotingMembers({required int peopleCount}) {
    return _demoMembers(peopleCount)
        .map(
          (member) =>
              member.copyWith(isReady: true, hasCompletedVoting: member.isHost),
        )
        .toList();
  }

  List<RoomMember> completeNextVotingMember(List<RoomMember> members) {
    final nextIndex = members.indexWhere(
      (member) => !member.isHost && !member.hasCompletedVoting,
    );
    if (nextIndex == -1) {
      return members;
    }

    return [
      for (var index = 0; index < members.length; index++)
        index == nextIndex
            ? members[index].copyWith(hasCompletedVoting: true)
            : members[index],
    ];
  }

  List<RoomMember> _demoMembers(int peopleCount) {
    return List.generate(peopleCount, (index) {
      return RoomMember(
        id: index == 0 ? 'host' : 'member-$index',
        name: '参加者 ${index + 1}',
        avatarUrl: null,
        isHost: index == 0,
        isMe: index == 0,
        isReady: false,
        hasCompletedVoting: false,
      );
    });
  }
}

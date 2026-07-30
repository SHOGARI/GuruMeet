import '../core/demo_config.dart';
import '../core/invite_config.dart';

class GroupCreationDraft {
  const GroupCreationDraft({
    required this.peopleCount,
    required this.area,
    required this.budget,
    required this.groupId,
    this.locationId,
    required this.isHost,
    this.roomId,
  });

  factory GroupCreationDraft.createMock({
    required int peopleCount,
    required String area,
    required BudgetOption budget,
    String? locationId,
  }) {
    if (DemoConfig.isDemoMode) {
      return GroupCreationDraft(
        peopleCount: peopleCount,
        area: area,
        budget: budget,
        groupId: DemoConfig.roomCode,
        locationId: locationId,
        isHost: true,
        roomId: null,
      );
    }

    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    var value = DateTime.now().microsecondsSinceEpoch;
    final characters = <String>[];

    for (var index = 0; index < 5; index++) {
      characters.add(alphabet[value % alphabet.length]);
      value ~/= alphabet.length;
    }
    final groupCode = characters.reversed.join();

    return GroupCreationDraft(
      peopleCount: peopleCount,
      area: area,
      budget: budget,
      groupId: groupCode,
      locationId: locationId,
      isHost: true,
      roomId: null,
    );
  }

  factory GroupCreationDraft.joinMock({required String groupId}) {
    return GroupCreationDraft(
      peopleCount: 4,
      area: '新宿',
      budget: BudgetOption.from2000To3000,
      groupId: groupId.toUpperCase(),
      locationId: null,
      isHost: false,
      roomId: null,
    );
  }

  factory GroupCreationDraft.fromApi({
    required String roomId,
    required String groupId,
    required int peopleCount,
    required String area,
    required BudgetOption budget,
    required bool isHost,
    String? locationId,
  }) {
    return GroupCreationDraft(
      peopleCount: peopleCount,
      area: area,
      budget: budget,
      groupId: groupId.toUpperCase(),
      locationId: locationId,
      isHost: isHost,
      roomId: roomId,
    );
  }

  final int peopleCount;
  final String area;
  final BudgetOption budget;
  final String groupId;
  final String? locationId;
  final bool isHost;
  final String? roomId;

  String get inviteToken => roomId ?? groupId;
  String get inviteUrl => '${InviteConfig.baseUrl}/#/join/$inviteToken';
}

enum BudgetOption {
  under1000('1,000円以下', null, 1000),
  from1000To2000('1,000〜2,000円', 1000, 2000),
  from2000To3000('2,000〜3,000円', 2000, 3000),
  from3000To5000('3,000〜5,000円', 3000, 5000),
  over5000('5,000円以上', 5000, null);

  const BudgetOption(this.label, this.minAmount, this.maxAmount);

  factory BudgetOption.fromRange({int? minAmount, int? maxAmount}) {
    for (final option in values) {
      if (option.minAmount == minAmount && option.maxAmount == maxAmount) {
        return option;
      }
    }
    return BudgetOption.from2000To3000;
  }

  final String label;
  final int? minAmount;
  final int? maxAmount;
}

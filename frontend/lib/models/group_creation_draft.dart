class GroupCreationDraft {
  const GroupCreationDraft({
    required this.peopleCount,
    required this.area,
    required this.budget,
    required this.groupId,
  });

  factory GroupCreationDraft.createMock({
    required int peopleCount,
    required String area,
    required BudgetOption budget,
  }) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    var value = DateTime.now().microsecondsSinceEpoch;
    final characters = <String>[];

    for (var index = 0; index < 4; index++) {
      characters.add(alphabet[value % alphabet.length]);
      value ~/= alphabet.length;
    }
    final groupCode = characters.reversed.join();

    return GroupCreationDraft(
      peopleCount: peopleCount,
      area: area,
      budget: budget,
      groupId: groupCode,
    );
  }

  factory GroupCreationDraft.joinMock({required String groupId}) {
    return GroupCreationDraft(
      peopleCount: 4,
      area: '新宿',
      budget: BudgetOption.from2000To3000,
      groupId: groupId.toUpperCase(),
    );
  }

  final int peopleCount;
  final String area;
  final BudgetOption budget;
  final String groupId;

  String get inviteUrl => 'https://gurumeet.app/join/$groupId';
}

enum BudgetOption {
  under1000('1,000円以下'),
  from1000To2000('1,000〜2,000円'),
  from2000To3000('2,000〜3,000円'),
  from3000To5000('3,000〜5,000円'),
  over5000('5,000円以上');

  const BudgetOption(this.label);

  final String label;
}

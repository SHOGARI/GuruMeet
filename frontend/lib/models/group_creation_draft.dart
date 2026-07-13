class GroupCreationDraft {
  const GroupCreationDraft({
    required this.peopleCount,
    required this.area,
    required this.budget,
  });

  final int peopleCount;
  final String area;
  final BudgetOption budget;

  String get inviteUrl => 'https://gurumeet.app/join/demo-group';
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

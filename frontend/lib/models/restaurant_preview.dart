class RestaurantPreview {
  const RestaurantPreview({
    required this.id,
    required this.name,
    required this.area,
    required this.budget,
    required this.cuisine,
    required this.description,
    required this.imageUrls,
    this.distance = '徒歩圏内',
    this.openingHours = '17:00〜23:00',
    this.address = '住所未設定',
  });

  final String id;
  final String name;
  final String area;
  final String budget;
  final String cuisine;
  final String description;
  final List<String> imageUrls;
  final String distance;
  final String openingHours;
  final String address;

  String get imageUrl => imageUrls.isEmpty ? '' : imageUrls.first;
}

class RestaurantVoteResult {
  const RestaurantVoteResult({
    required this.restaurant,
    required this.likeCount,
    required this.rejectCount,
  });

  final RestaurantPreview restaurant;
  final int likeCount;
  final int rejectCount;
}

class RestaurantMatchResult {
  const RestaurantMatchResult({
    required this.restaurant,
    required this.results,
    required this.peopleCount,
    this.decidedRestaurantId,
  });

  final RestaurantPreview restaurant;
  final List<RestaurantVoteResult> results;
  final int peopleCount;
  final String? decidedRestaurantId;

  int get matchedLikeCount => _resultFor(restaurant).likeCount;

  RestaurantVoteResult _resultFor(RestaurantPreview target) {
    return results.firstWhere(
      (result) => result.restaurant.id == target.id,
      orElse: () => RestaurantVoteResult(
        restaurant: target,
        likeCount: 0,
        rejectCount: peopleCount,
      ),
    );
  }
}

const mockRestaurants = [
  RestaurantPreview(
    id: 'ginza-sora',
    name: 'GINZA SORA',
    area: '銀座',
    budget: '3,000〜5,000円',
    cuisine: 'モダンビストロ',
    description: '旬の食材を気軽に楽しめる、落ち着いた雰囲気のビストロ。',
    distance: '現在地から1.2km',
    openingHours: '11:30〜15:00 / 17:00〜23:00',
    address: '東京都中央区銀座3-5-7',
    imageUrls: [
      'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=1200&q=85',
      'https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=1200&q=85',
      'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&w=1200&q=85',
    ],
  ),
  RestaurantPreview(
    id: 'kitchen-noka',
    name: 'KITCHEN noka',
    area: '代々木上原',
    budget: '2,000〜3,000円',
    cuisine: 'イタリアン',
    description: 'シェアしやすい料理と自然派ワインが揃うカジュアルダイニング。',
    distance: '現在地から2.8km',
    openingHours: '17:30〜23:30',
    address: '東京都渋谷区上原1-18-6',
    imageUrls: [
      'https://images.unsplash.com/photo-1544148103-0773bf10d330?auto=format&fit=crop&w=1200&q=85',
      'https://images.unsplash.com/photo-1551218808-94e220e084d2?auto=format&fit=crop&w=1200&q=85',
      'https://images.unsplash.com/photo-1559339352-11d035aa65de?auto=format&fit=crop&w=1200&q=85',
    ],
  ),
  RestaurantPreview(
    id: 'shokudo-koharu',
    name: '食堂 こはる',
    area: '中目黒',
    budget: '2,000〜3,000円',
    cuisine: '創作和食',
    description: 'みんなで囲める季節の小皿料理が人気の、居心地のよい食堂。',
    distance: '現在地から3.4km',
    openingHours: '12:00〜14:30 / 18:00〜23:00',
    address: '東京都目黒区上目黒2-12-4',
    imageUrls: [
      'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=85',
      'https://images.unsplash.com/photo-1523905330026-b8bd1f5f320e?auto=format&fit=crop&w=1200&q=85',
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=85',
    ],
  ),
  RestaurantPreview(
    id: 'tacos-luma',
    name: 'TACOS LUMA',
    area: '恵比寿',
    budget: '1,000〜2,000円',
    cuisine: 'メキシカン',
    description: '香ばしいタコスと軽いドリンクで、短時間でも盛り上がれる一軒。',
    distance: '現在地から2.1km',
    openingHours: '11:00〜22:30',
    address: '東京都渋谷区恵比寿南1-9-3',
    imageUrls: [
      'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?auto=format&fit=crop&w=1200&q=85',
      'https://images.unsplash.com/photo-1565299507177-b0ac66763828?auto=format&fit=crop&w=1200&q=85',
      'https://images.unsplash.com/photo-1624300629298-e9de39c13be8?auto=format&fit=crop&w=1200&q=85',
    ],
  ),
  RestaurantPreview(
    id: 'noodle-haru',
    name: 'NOODLE HARU',
    area: '下北沢',
    budget: '1,000円以下',
    cuisine: 'ラーメン',
    description: '締めにも一軒目にも使いやすい、澄んだスープが人気のヌードルバー。',
    distance: '現在地から4.6km',
    openingHours: '11:30〜24:00',
    address: '東京都世田谷区北沢2-21-8',
    imageUrls: [
      'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=1200&q=85',
      'https://images.unsplash.com/photo-1617093727343-374698b1b08d?auto=format&fit=crop&w=1200&q=85',
      'https://images.unsplash.com/photo-1557872943-16a5ac26437e?auto=format&fit=crop&w=1200&q=85',
    ],
  ),
];

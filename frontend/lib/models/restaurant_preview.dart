class RestaurantPreview {
  const RestaurantPreview({
    required this.id,
    required this.name,
    required this.area,
    required this.budget,
    required this.cuisine,
    required this.description,
    required this.imageUrl,
  });

  final String id;
  final String name;
  final String area;
  final String budget;
  final String cuisine;
  final String description;
  final String imageUrl;
}

const mockRestaurants = [
  RestaurantPreview(
    id: 'ginza-sora',
    name: 'GINZA SORA',
    area: '銀座',
    budget: '3,000〜5,000円',
    cuisine: 'モダンビストロ',
    description: '旬の食材を気軽に楽しめる、落ち着いた雰囲気のビストロ。',
    imageUrl:
        'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=1200&q=85',
  ),
  RestaurantPreview(
    id: 'kitchen-noka',
    name: 'KITCHEN noka',
    area: '代々木上原',
    budget: '2,000〜3,000円',
    cuisine: 'イタリアン',
    description: 'シェアしやすい料理と自然派ワインが揃うカジュアルダイニング。',
    imageUrl:
        'https://images.unsplash.com/photo-1544148103-0773bf10d330?auto=format&fit=crop&w=1200&q=85',
  ),
  RestaurantPreview(
    id: 'shokudo-koharu',
    name: '食堂 こはる',
    area: '中目黒',
    budget: '2,000〜3,000円',
    cuisine: '創作和食',
    description: 'みんなで囲める季節の小皿料理が人気の、居心地のよい食堂。',
    imageUrl:
        'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=85',
  ),
  RestaurantPreview(
    id: 'tacos-luma',
    name: 'TACOS LUMA',
    area: '恵比寿',
    budget: '1,000〜2,000円',
    cuisine: 'メキシカン',
    description: '香ばしいタコスと軽いドリンクで、短時間でも盛り上がれる一軒。',
    imageUrl:
        'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?auto=format&fit=crop&w=1200&q=85',
  ),
  RestaurantPreview(
    id: 'noodle-haru',
    name: 'NOODLE HARU',
    area: '下北沢',
    budget: '1,000円以下',
    cuisine: 'ラーメン',
    description: '締めにも一軒目にも使いやすい、澄んだスープが人気のヌードルバー。',
    imageUrl:
        'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=1200&q=85',
  ),
];

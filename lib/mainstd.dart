import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Microsoft Rewards Keywords',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const KeywordListScreen(),
    );
  }
}

class KeywordListScreen extends StatelessWidget {
  const KeywordListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Microsoft Rewards Keywords'),
      ),
      body: ListView.builder(
        itemCount: keywordCategories.length,
        itemBuilder: (context, index) {
          final category = keywordCategories[index];
          return ExpansionTile(
            title: Text(category.name),
            children: category.keywords.map((keyword) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Chip(
                  label: Text(keyword),
                  backgroundColor: Colors.blue.shade100,
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class KeywordCategory {
  final String name;
  final List<String> keywords;

  KeywordCategory({required this.name, required this.keywords});
}

final List<KeywordCategory> keywordCategories = [
  KeywordCategory(
    name: '買い物',
    keywords: ['shopping', 'shopping list', 'Amazon'],
  ),
  KeywordCategory(
    name: '曲の歌詞',
    keywords: ['beat it lyrics', 'beat it lyrics michael jackson'],
  ),
  KeywordCategory(
    name: 'レシピ',
    keywords: ['焼きそば　レシピ', 'レシピ　人気'],
  ),
  KeywordCategory(
    name: '映画',
    keywords: ['movie', 'star wars movies', 'movie star wars 1977'],
  ),
  KeywordCategory(
    name: '地元のレストラン',
    keywords: ['近くのマクドナルド', '近くのすかいらーく', '東京 イタリアン'],
  ),
  KeywordCategory(
    name: '天気',
    keywords: ['天気', '天気予報', '東京　天気', 'weather'],
  ),
  KeywordCategory(
    name: '旅行・フライト',
    keywords: ['flight', 'フライト', 'フライト tokyo', '飛行機', '東京 飛行機', 'JAL', 'flight tokyo to seoul'],
  ),
  KeywordCategory(
    name: 'ホテル',
    keywords: ['hotel', 'tokyo hotel', 'ホテル予約'],
  ),
  KeywordCategory(
    name: '冒険先・目的地',
    keywords: ['東京', '秋芳洞'],
  ),
  KeywordCategory(
    name: '不動産',
    keywords: ['東京　不動産'],
  ),
  KeywordCategory(
    name: '為替レート',
    keywords: ['ドル円', 'ドル円　レート'],
  ),
  KeywordCategory(
    name: '荷物追跡',
    keywords: ['ups tracking'],
  ),
  KeywordCategory(
    name: '翻訳',
    keywords: ['translate', '翻訳　日本語', '英語でりんご', 'Translate word to japanese'],
  ),
  KeywordCategory(
    name: '最新ニュース',
    keywords: ['ニュース', 'news', 'FOMC'],
  ),
  KeywordCategory(
    name: '職種を検索',
    keywords: ['job', 'job search', 'job openings at Amazon'],
  ),
  KeywordCategory(
    name: '健康状態・病気を検索',
    keywords: ['health', '症状', '腹痛 原因'],
  ),
  KeywordCategory(
    name: 'ビデオゲームを検索',
    keywords: ['game', 'フォートナイト'],
  ),
  KeywordCategory(
    name: '経済・金融市場を検索',
    keywords: ['nasdaq 100', 'ナスダック', 'dow index'],
  ),
  KeywordCategory(
    name: 'スポーツ',
    keywords: ['ドジャース 速報'],
  ),
  KeywordCategory(
    name: 'よく知らないワードの意味を検索',
    keywords: ['誤謬', '誤謬 意味'],
  ),
  KeywordCategory(
    name: '選挙の最新情報を検索',
    keywords: ['trump harris odds', 'election'],
  ),
  KeywordCategory(
    name: '別のタイムゾーンの時間を確認',
    keywords: ['アメリカ　時間', 'utc time now'],
  ),
];
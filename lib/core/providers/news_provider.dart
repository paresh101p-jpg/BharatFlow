import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:bharat_flow/core/constants/api_keys.dart';
import 'package:bharat_flow/core/utils/api_tracker.dart';

class NewsItem {
  final String id;
  final String title;
  final String summary;
  final String content;
  final String? imageUrl;
  final String sourceUrl;
  final DateTime publishedAt;

  NewsItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    this.imageUrl,
    required this.sourceUrl,
    required this.publishedAt,
  });

  factory NewsItem.fromMap(Map<String, dynamic> map) {
    return NewsItem(
      id: map['id']?.toString() ?? '',
      title: map['title'] ?? '',
      summary: map['summary'] ?? '',
      content: map['content'] ?? '',
      imageUrl: map['image_url'],
      sourceUrl: map['source_url'] ?? '',
      publishedAt: DateTime.parse(
        map['published_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class NewsNotifier extends StateNotifier<AsyncValue<List<NewsItem>>> {
  bool _isSyncing = false;
  final _supabase = Supabase.instance.client;

  NewsNotifier() : super(const AsyncValue.loading()) {
    fetchNews();
  }

  Future<void> fetchNews({bool force = false}) async {
    try {
      final currentData = state.value;
      if (currentData == null || currentData.isEmpty) {
        state = const AsyncValue.loading();
      }

      final threeDaysAgo = DateTime.now()
          .subtract(const Duration(days: 3))
          .toIso8601String();

      // Permanent cleanup: Delete news older than 3 days from the database
      try {
        await _supabase.from('app_news').delete().lt('published_at', threeDaysAgo);
      } catch (_) {}

      final res = await _supabase
          .from('app_news')
          .select()
          .gt('published_at', threeDaysAgo)
          .order('published_at', ascending: false)
          .limit(40);

      final newsList =
          (res as List).map((e) => NewsItem.fromMap(e)).toList();

      state = AsyncValue.data(newsList);
      debugPrint('📊 Final News Count: ${newsList.length}');

      if (newsList.isEmpty ||
          (newsList.isNotEmpty &&
              DateTime.now()
                      .difference(newsList.first.publishedAt)
                      .inHours >=
                  2) ||
          force) {
        _syncNews();
      }
    } catch (e, st) {
      debugPrint('News Load Error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _syncNews() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      debugPrint('🔄 Attempting Sync: NewsData.io');
      final response = await http.get(Uri.parse(
        'https://newsdata.io/api/1/news'
        '?apikey=${ApiKeys.newsDataApiKey}'
        '&country=in&language=hi'
        '&q=kisan+fasal+mandi+krishi&size=10',
      ));
      ApiTracker.logCall('NewsData.io: Get Agri News', statusCode: response.statusCode);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final articles = (data['results'] as List?) ?? [];
        if (articles.isNotEmpty) {
          debugPrint('✅ NewsData found ${articles.length} articles');
          await _processArticles(articles);
        }
      }
    } catch (e) {
      debugPrint('NewsData Error: $e');
    }

    await _syncWithRSS();
    _isSyncing = false;
    fetchNews(force: false);
  }

  Future<void> _syncWithRSS() async {
    final sources = [
      'https://news.google.com/rss/search?q=kisan+kheti+mandi+when:24h&hl=hi&gl=IN&ceid=IN:hi',
      'https://hindi.krishijagran.com/rss/news/',
      'https://www.jagran.com/rss/news/business_agriculture.xml',
      'https://www.gaonconnection.com/feed',
      'https://hindi.news18.com/rss/khabar/nation/agriculture.xml',
    ];

    for (final url in sources) {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 10));
        ApiTracker.logCall('RSS Feed: $url', statusCode: response.statusCode);

        if (response.statusCode != 200) continue;
        final body = utf8.decode(response.bodyBytes, allowMalformed: true);
        final items = body.split(RegExp(r'<item.*?>'));
        final articles = <Map<String, dynamic>>[];

        for (var i = 1; i < items.length && i <= 15; i++) {
          final title = _extractTag(items[i], 'title');
          final link = _extractTag(items[i], 'link');
          final description = _extractTag(items[i], 'description');
          
          // Improved image extraction
          String? imageUrl;
          
          // 1. Check media:content
          final mediaMatch = RegExp(r'<media:content.*?url="(.*?)"', caseSensitive: false).firstMatch(items[i]);
          if (mediaMatch != null) {
            imageUrl = mediaMatch.group(1);
          }
          
          // 2. Check enclosure
          if (imageUrl == null) {
            final enclosureMatch = RegExp(r'<enclosure.*?url="(.*?)"', caseSensitive: false).firstMatch(items[i]);
            if (enclosureMatch != null) {
              imageUrl = enclosureMatch.group(1);
            }
          }
          
          // 3. Check for <img> in description
          if (imageUrl == null && description.isNotEmpty) {
            final imgMatch = RegExp(r'<img.*?src="(.*?)"', caseSensitive: false).firstMatch(items[i]);
            if (imgMatch != null) {
              imageUrl = imgMatch.group(1);
            }
          }

          if (title.isNotEmpty && link.isNotEmpty) {
            articles.add({
              'title': title,
              'link': link,
              'description': description.isNotEmpty ? description : title,
              'image_url': imageUrl,
            });
          }
        }

        if (articles.isNotEmpty) {
          debugPrint('✅ Found ${articles.length} articles from $url');
          await _processArticles(articles);
        }
      } catch (e) {
        debugPrint('RSS Error ($url): $e');
      }
    }
  }

  String _extractTag(String xml, String tag) {
    try {
      final match = RegExp(
        '<$tag>(.*?)</$tag>',
        dotAll: true,
        caseSensitive: false,
      ).firstMatch(xml);
      if (match == null) return '';
      return match
          .group(1)!
          .replaceAll(RegExp(r'<!\[CDATA\[', caseSensitive: false), '')
          .replaceAll(RegExp(r'\]\]>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .trim();
    } catch (_) {
      return '';
    }
  }

  Future<void> _processArticles(List<dynamic> articles) async {
    for (final art in articles) {
      try {
        final title = (art['title'] ?? '').toString().trim();
        final sourceUrl =
            (art['link'] ?? art['source_url'] ?? '').toString().trim();

        if (title.isEmpty || sourceUrl.isEmpty) continue;

        String summary =
            (art['description'] ?? art['content'] ?? title)
                .toString()
                .replaceAll(RegExp(r'<[^>]*>'), '')
                .trim();

        if (summary.length > 300) {
          summary = '${summary.substring(0, 297)}...';
        }

        await _supabase.from('app_news').upsert(
          {
            'title': title,
            'summary': summary.isNotEmpty ? summary : title,
            'content': summary,
            'image_url': art['image_url'] ?? art['image'],
            'source_url': sourceUrl,
            'published_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'source_url',
        );

        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint('Article Error: $e');
      }
    }
  }

  void shareNews(NewsItem news) {
    const appLink =
        'https://play.google.com/store/apps/details?id=com.bharatflow.app';
    Share.share(
      '📢 *Bharat Flow Samachar* 🌾\n\n'
      '*${news.title}*\n\n'
      '${news.summary}\n\n'
      'Puri khabar aur Mandi bhav ke liye Bharat Flow download karein.\n'
      '📥 $appLink',
    );
  }
}

final newsProvider =
    StateNotifierProvider<NewsNotifier, AsyncValue<List<NewsItem>>>(
  (ref) => NewsNotifier(),
);
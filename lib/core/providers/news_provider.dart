import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:bharat_flow/core/services/config_service.dart';
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
    // News syncing is now handled entirely by the VPS backend.
    // The VPS pushes new articles directly to Supabase and sends FCM notifications.
    fetchNews(force: false);
  }

  Future<void> _syncWithRSS() async {
    // Moved to VPS backend.
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
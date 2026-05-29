import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:bharat_flow/core/providers/settings_provider.dart';
import 'package:bharat_flow/core/providers/location_provider.dart';
import 'package:bharat_flow/core/utils/language_helper.dart';

class TranslatedText extends ConsumerWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  const TranslatedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final location = ref.watch(locationProvider);

    // If English, return immediately without translation
    if (settings.language == 'English') {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        overflow: overflow,
        maxLines: maxLines,
      );
    }

    // Determine target lang code
    String lang = 'hi';
    switch (settings.language) {
      case 'Hindi': lang = 'hi'; break;
      case 'Gujarati': lang = 'gu'; break;
      case 'Punjabi': lang = 'pa'; break;
      case 'Marathi': lang = 'mr'; break;
      case 'Bengali': lang = 'bn'; break;
      case 'Telugu': lang = 'te'; break;
      case 'Tamil': lang = 'ta'; break;
      case 'Kannada': lang = 'kn'; break;
      case 'Malayalam': lang = 'ml'; break;
      default: lang = 'hi';
    }

    final translationBox = Hive.box('translations_cache');
    final String cacheKey = '${lang}_$text';

    // Synchronous hot path from Hive cache to prevent flickering
    if (translationBox.containsKey(cacheKey)) {
      return Text(
        translationBox.get(cacheKey) ?? text,
        style: style,
        textAlign: textAlign,
        overflow: overflow,
        maxLines: maxLines,
      );
    }

    // Fallback: translate on the fly
    return FutureBuilder<String>(
      future: LanguageHelper.translate(text, location.state, location.city),
      builder: (context, snapshot) {
        final translated = snapshot.data ?? text;
        return Text(
          translated,
          style: style,
          textAlign: textAlign,
          overflow: overflow,
          maxLines: maxLines,
        );
      },
    );
  }
}

import 'dart:typed_data';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bharat_flow/core/services/config_service.dart';

class AIService {
  // Google AI Studio API Key from central config
  static String get _apiKey => ConfigService.get('ai_service_gemini_key');
  final _model = GenerativeModel(model: 'gemini-1.5-flash-latest', apiKey: _apiKey);
  final _supabase = Supabase.instance.client;

  // --- AUTOMATIC FASAL SWAP ADVICE ---
  Future<String> getFasalSwapAdvice(String location, String currentCrop, String mandiPrice, String language) async {
    final langInstruction = language.toLowerCase() == 'hi' ? "Jawab ekdam saral Hindi mein do." : "Provide advice in simple English.";
    final prompt = """
    Aap ek expert kisan Salahkar (Agriculture Consultant) hain. 
    Location: $location. 
    Current Crop: $currentCrop. 
    Mandi Price: $mandiPrice.
    Should the farmer swap the crop? 
    Suggest a crop that consumes less water and gives high profit. 
    $langInstruction
    """;

    try {
      // Primary: 1.5 Flash
      final model = GenerativeModel(model: 'gemini-1.5-flash-latest', apiKey: _apiKey);
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? "No response";
    } catch (e) {
      print('Gemini 1.5 Flash failed, trying Gemini Pro: $e');
      try {
        // Fallback: Gemini Pro (Stable)
        final model = GenerativeModel(model: 'gemini-pro', apiKey: _apiKey);
        final response = await model.generateContent([Content.text(prompt)]);
        return response.text ?? "No response from Gemini Pro";
      } catch (e2) {
        return "Gemini Error: $e2";
      }
    }
  }

  // --- PHOTO SE BIMARI PEHCHANNA ---
  Future<String> detectDisease(XFile image, String language) async {
    try {
      final bytes = await image.readAsBytes();
      final langInstruction = language.toLowerCase() == 'hi' ? "Jawab Hindi mein dein." : "Answer in English.";
      final prompt = TextPart("Aap ek kisan mitra AI hain. Is photo ko dekh kar batayein ki fasal mein kya dikkat hai aur uska sasta desi ilaaj kya hai? $langInstruction");
      final imagePart = DataPart('image/jpeg', bytes);

      // Primary: 1.5 Flash (supports multi-modal)
      final model = GenerativeModel(model: 'gemini-1.5-flash-latest', apiKey: _apiKey);
      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      return response.text ?? "Photo clear nahi hai.";
    } catch (e) {
      print('Gemini 1.5 Flash failed, trying Gemini Pro Vision: $e');
      try {
        final bytes = await image.readAsBytes();
        final prompt = TextPart("Is photo ko dekh kar batayein ki fasal mein kya dikkat hai aur uska sasta desi ilaaj kya hai?");
        final imagePart = DataPart('image/jpeg', bytes);
        
        final model = GenerativeModel(model: 'gemini-pro-vision', apiKey: _apiKey);
        final response = await model.generateContent([
          Content.multi([prompt, imagePart])
        ]);
        return response.text ?? "No response from Vision model";
      } catch (e2) {
        return "Gemini Error: $e2";
      }
    }
  }

  // --- SOIL HEALTH CARD ANALYSIS ---
  Future<Map<String, dynamic>?> analyzeSoilCard(XFile image, String location) async {
    try {
      final bytes = await image.readAsBytes();
      final prompt = TextPart("""
        Analyze this Soil Health Card image. 
        1. Extract N (Nitrogen), P (Phosphorus), K (Potassium), and pH level. 
        2. Give a Health Score (0-100%). 
        3. Suggest 3 best crops for this soil and exact fertilizer dosage (e.g., Urea, DAP) for the location: $location. 
        4. Check current Weather and advise. 
        IMPORTANT: Provide all suggestions and advice in simple Hindi/Gujarati as appropriate for the farmer.
        Return ONLY a JSON object with keys: n, p, k, ph, carbon, health_score, crop_suggestions, fertilizer_dosage, weather_advice.
      """);
      final imagePart = DataPart('image/jpeg', bytes);

      final model = GenerativeModel(model: 'gemini-1.5-pro-latest', apiKey: _apiKey);
      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      final text = response.text;
      if (text == null) return null;

      try {
        // Find the first '{' and last '}' to extract JSON even if there's chatter
        final start = text.indexOf('{');
        final end = text.lastIndexOf('}');
        if (start == -1 || end == -1) throw "No JSON found";
        
        final jsonStr = text.substring(start, end + 1);
        return json.decode(jsonStr);
      } catch (e) {
        print('❌ JSON Extraction Error: $e | RAW: $text');
        return null;
      }
    } catch (e) {
      print('❌ Soil Analysis Global Error: $e');
      return null;
    }
  }

}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/providers/general_providers.dart';
import '../../../../features/profile/data/repositories/profile_repository.dart';
import '../../../../core/services/config_service.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

// Base Realtime stream for ALL accessible questions to prevent multiple channel conflicts
final allHelplineQuestionsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) return Stream.value([]);

  // Proactive auto-pruning of questions older than 365 days (runs in the background)
  _pruneOlderQuestions(supabase);

  try {
    return supabase
        .from('helpline_questions')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((response) => List<Map<String, dynamic>>.from(response));
  } catch (e) {
    print('Error subscribing to base helpline questions stream: $e');
    return Stream.value([]);
  }
});

// 1. Fetch user's own questions
final helplineQuestionsProvider = Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  final allQuestions = ref.watch(allHelplineQuestionsProvider);
  return allQuestions.whenData((list) => list.where((item) => item['user_id'] == user?.id).toList());
});

void _pruneOlderQuestions(SupabaseClient supabase) async {
  try {
    final cutoff = DateTime.now().subtract(const Duration(days: 365)).toIso8601String();
    await supabase
        .from('helpline_questions')
        .delete()
        .lt('created_at', cutoff);
  } catch (e) {
    // Fail silently so it doesn't block fetching if database triggers are active
    print('Auto-pruning older questions failed: $e');
  }
}

// 2. Fetch public answered questions in real-time for the Community Forum
final communityForumProvider = Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final allQuestions = ref.watch(allHelplineQuestionsProvider);
  return allQuestions.whenData((list) => list
      .where((item) => item['is_public'] == true && (item['status'] == 'Replied' || item['status'] == 'Approved'))
      .toList());
});

// 2b. Fetch community answers for a specific question
final helplineAnswersProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, questionId) {
  final supabase = Supabase.instance.client;
  try {
    return supabase
        .from('helpline_answers')
        .stream(primaryKey: ['id'])
        .eq('question_id', questionId)
        .order('created_at', ascending: true)
        .map((response) => List<Map<String, dynamic>>.from(response));
  } catch (e) {
    print('Error loading answers stream: $e');
    return Stream.value([]);
  }
});

// 3. Notifier to handle submits (image uploads + inserts)
class HelplineNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  HelplineNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<bool> canSubmitQuestion() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return false;

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
      
      final countResponse = await supabase
          .from('helpline_questions')
          .select('id')
          .eq('user_id', user.id)
          .gte('created_at', startOfDay);
          
      return (countResponse as List).length < 3;
    } catch (e) {
      print('[HELPLINE] Error checking daily limit: $e');
      return true; // Allow if check fails to prevent blocking user completely
    }
  }

  Future<bool> submitQuestion({
    required String category,
    required String questionText,
    File? imageFile,
  }) async {
    state = const AsyncValue.loading();
    print('[HELPLINE] submitQuestion initiated: Category=$category, Text length=${questionText.length}, Image present=${imageFile != null}');
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      String? imageUrl;
      if (imageFile != null) {
        print('[HELPLINE] Local Image path for upload: ${imageFile.path}');
        final repo = ref.read(generalRepositoryProvider);
        // Upload photo to Supabase storage bucket 'helpline_photos'
        final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        imageUrl = await repo.uploadFile('helpline_photos', fileName, imageFile);
        print('[HELPLINE] Storage Upload result: $imageUrl');
        
        if (imageUrl == null) {
          print('[HELPLINE] WARNING: Storage upload returned null.');
        }
      }

      final profileAsync = ref.read(profileProvider);
      final profile = profileAsync.value;

      final data = {
        'user_id': user.id,
        'user_name': profile?.fullName ?? user.email?.split('@').first ?? 'Kisan',
        'user_avatar': profile?.avatarUrl,
        'user_city': profile?.city ?? 'Surat',
        'user_state': profile?.fullAddress != null && profile!.fullAddress!.contains(',')
            ? profile.fullAddress!.split(',').last.trim()
            : 'Gujarat',
        'category': category,
        'question_text': questionText,
        'image_url': imageUrl ?? '',
        'status': 'Pending',
        'is_public': true,
      };

      // Direct insert via supabase client to get the returned data containing the new ID
      final response = await supabase
          .from('helpline_questions')
          .insert(data)
          .select()
          .single();

      final String newQuestionId = response['id']?.toString() ?? '';
      
      if (newQuestionId.isNotEmpty) {
        // Trigger Resend API call in the background to avoid blocking user flow
        _sendEmailNotification(newQuestionId, data);

        ref.invalidate(helplineQuestionsProvider);
        ref.invalidate(communityForumProvider);
        state = const AsyncValue.data(null);
        return true;
      } else {
        throw Exception('Insert query failed');
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Sends a gorgeous glassmorphic style email notification to the administrator
  Future<void> _sendEmailNotification(String questionId, Map<String, dynamic> data) async {
    try {
      final apiKey = ConfigService.get('resend_api_key');
      if (apiKey.isEmpty) {
        print('[ERROR] Resend API key not found in configs.');
        return;
      }

      final farmerName = data['user_name'] ?? 'Kisan';
      final category = data['category'] ?? 'other';
      final questionText = data['question_text'] ?? '';
      final city = data['user_city'] ?? 'Surat';
      final state = data['user_state'] ?? 'Gujarat';
      final imageUrl = data['image_url'] ?? '';

      final Map<String, String> categoryLabels = {
        'crop_disease': 'Crop Disease / फसल रोग 🌾',
        'mandi_bhav': 'Mandi Bhav / मंडी भाव 📈',
        'mausam': 'Weather / मौसम 🌦️',
        'govt_schemes': 'Govt Schemes / सरकारी योजनाएं 📜',
        'other': 'Other / अन्य ⚙️'
      };
      final readableCategory = categoryLabels[category] ?? category;

      // Link leads directly to the newly hosted expert reply portal
      final replyLink = 'https://paresh101p-jpg.github.io/BharatFlow/helpline_reply.html?id=$questionId&token=$apiKey';

      final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>New BharatFlow Q&A Ticket</title>
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f6f9fc; padding: 20px; margin: 0; -webkit-font-smoothing: antialiased;">
    <div style="max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.05); border: 1px solid #eef2f6;">
        <!-- Header -->
        <div style="background: linear-gradient(135deg, #10b981, #059669); padding: 30px; text-align: center; color: #ffffff;">
            <div style="font-size: 40px; margin-bottom: 10px;">🌾</div>
            <h1 style="font-size: 24px; font-weight: 800; margin: 0; letter-spacing: -0.5px;">New Kisan Helpline Question</h1>
            <p style="font-size: 14px; opacity: 0.9; margin: 5px 0 0 0;">भारतफ्लो किसान हेल्पलाइन - नया प्रश्न प्राप्त हुआ</p>
        </div>

        <div style="padding: 30px;">
            <!-- Farmer Profile -->
            <h3 style="font-size: 12px; font-weight: 800; text-transform: uppercase; letter-spacing: 1px; color: #10b981; margin: 0 0 15px 0; border-bottom: 1px solid #eef2f6; padding-bottom: 5px;">Farmer Details (विवरण)</h3>
            <table style="width: 100%; border-collapse: collapse; margin-bottom: 25px; font-size: 14px;">
                <tr>
                    <td style="padding: 6px 0; color: #64748b; font-weight: 600; width: 40%;">Name (किसान का नाम):</td>
                    <td style="padding: 6px 0; color: #1e293b; font-weight: 700;">$farmerName</td>
                </tr>
                <tr>
                    <td style="padding: 6px 0; color: #64748b; font-weight: 600;">Category (श्रेणी):</td>
                    <td style="padding: 6px 0; color: #1e293b; font-weight: 700;">$readableCategory</td>
                </tr>
                <tr>
                    <td style="padding: 6px 0; color: #64748b; font-weight: 600;">Location (स्थान):</td>
                    <td style="padding: 6px 0; color: #1e293b; font-weight: 700;">$city, $state</td>
                </tr>
            </table>

            <!-- Question -->
            <h3 style="font-size: 12px; font-weight: 800; text-transform: uppercase; letter-spacing: 1px; color: #10b981; margin: 0 0 15px 0; border-bottom: 1px solid #eef2f6; padding-bottom: 5px;">Question Text (किसान का सवाल)</h3>
            <div style="background: #f8fafc; border-left: 4px solid #10b981; border-radius: 4px; padding: 15px 20px; font-size: 15px; color: #1e293b; font-weight: 500; line-height: 1.6; margin-bottom: 25px;">
                “ $questionText ”
            </div>

            <!-- Image Attachment -->
            ${imageUrl.isNotEmpty ? '''
            <h3 style="font-size: 12px; font-weight: 800; text-transform: uppercase; letter-spacing: 1px; color: #10b981; margin: 0 0 15px 0; border-bottom: 1px solid #eef2f6; padding-bottom: 5px;">Crop Photo Attachment</h3>
            <div style="margin-bottom: 25px; text-align: center; background: #fafafa; padding: 10px; border-radius: 8px; border: 1px solid #e2e8f0;">
                <img src="$imageUrl" alt="Crop Photo" style="max-width: 100%; max-height: 300px; border-radius: 4px; object-fit: contain;">
            </div>
            ''' : ''}

            <!-- Direct Actions -->
            <div style="text-align: center; margin-top: 30px; margin-bottom: 15px;">
                <a href="$replyLink" target="_blank" style="display: inline-block; background: linear-gradient(135deg, #10b981, #059669); color: #ffffff; text-decoration: none; padding: 14px 30px; border-radius: 10px; font-size: 16px; font-weight: 700; box-shadow: 0 4px 10px rgba(16,185,129,0.25);">
                    Write Solution / उत्तर दें 📝
                </a>
            </div>
            <p style="text-align: center; font-size: 12px; color: #94a3b8; margin: 0;">
                Link opens the secure expert answer submission portal.
            </p>
        </div>

        <!-- Footer -->
        <div style="background-color: #f8fafc; padding: 20px; text-align: center; font-size: 11px; color: #94a3b8; border-top: 1px solid #eef2f6;">
            BharatFlow secure messaging service. Sent to paresh101p@gmail.com.<br>
            Please don't forward this email to ensure ticket authenticity.
        </div>
    </div>
</body>
</html>
''';

      final emailBody = {
        'from': 'BharatFlow Helpline <onboarding@resend.dev>',
        'to': 'paresh101p@gmail.com',
        'subject': 'New Farmer Question from $farmerName ($readableCategory)',
        'html': htmlContent,
      };

      final response = await http.post(
        Uri.parse('https://api.resend.com/emails'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(emailBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('[SUCCESS] Direct Resend Helpline Notification sent successfully!');
      } else {
        print('[ERROR] Resend API failed: ${response.statusCode} | ${response.body}');
      }
    } catch (e) {
      print('[ERROR] Failed to send email via Resend API: $e');
    }
  }

  /// Permanently deletes a question submitted by the user
  Future<bool> deleteQuestion(String questionId) async {
    state = const AsyncValue.loading();
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Fetch the question first to get the image_url
      final questionData = await supabase
          .from('helpline_questions')
          .select('image_url')
          .eq('id', questionId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (questionData != null && questionData['image_url'] != null) {
        final String imageUrl = questionData['image_url'];
        if (imageUrl.isNotEmpty) {
          final uri = Uri.parse(imageUrl);
          final pathSegments = uri.pathSegments;
          final bucketIndex = pathSegments.indexOf('helpline_photos');
          if (bucketIndex != -1 && bucketIndex + 1 < pathSegments.length) {
             final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
             try {
                await supabase.storage.from('helpline_photos').remove([filePath]);
                print('[HELPLINE] Deleted image from storage: $filePath');
             } catch (e) {
                print('[HELPLINE] Warning: failed to delete image from storage: $e');
             }
          }
        }
      }

      await supabase
          .from('helpline_questions')
          .delete()
          .eq('id', questionId)
          .eq('user_id', user.id);

      // Invalidate the providers to refresh lists across screens and forums instantly
      ref.invalidate(helplineQuestionsProvider);
      ref.invalidate(communityForumProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Adds a reply to a public question in the community forum
  Future<bool> addAnswer({
    required String questionId,
    required String answerText,
  }) async {
    state = const AsyncValue.loading();
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final profileAsync = ref.read(profileProvider);
      final profile = profileAsync.value;

      final data = {
        'question_id': questionId,
        'user_id': user.id,
        'user_name': profile?.fullName ?? user.email?.split('@').first ?? 'Kisan',
        'user_avatar': profile?.avatarUrl,
        'answer_text': answerText,
      };

      await supabase.from('helpline_answers').insert(data);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> submitAnswer({
    required String questionId,
    required String answerText,
  }) async {
    state = const AsyncValue.loading();
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final profileAsync = ref.read(profileProvider);
      final profile = profileAsync.value;

      final data = {
        'question_id': questionId,
        'user_id': user.id,
        'user_name': profile?.fullName ?? user.email?.split('@').first ?? 'Kisan',
        'answer_text': answerText,
        'created_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('helpline_answers').insert(data);
      
      state = const AsyncValue.data(null);
      return true;
    } catch (e) {
      print('[HELPLINE] Error submitting answer: $e');
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }
}

final helplineNotifierProvider = StateNotifierProvider<HelplineNotifier, AsyncValue<void>>((ref) {
  return HelplineNotifier(ref);
});

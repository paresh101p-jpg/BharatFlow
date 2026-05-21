import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/settings_provider.dart';
import '../providers/helpline_provider.dart';

class AskExpertScreen extends ConsumerStatefulWidget {
  const AskExpertScreen({super.key});

  @override
  ConsumerState<AskExpertScreen> createState() => _AskExpertScreenState();
}

class _AskExpertScreenState extends ConsumerState<AskExpertScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _questionController = TextEditingController();
  String _selectedCategory = 'crop_disease';
  File? _selectedImage;
  bool _isSubmitting = false;

  // Selected category chip for the Community Forum
  String _selectedForumCategory = 'All';

  // State to track locally liked community questions for dynamic response
  final Set<String> _likedQuestions = {};

  final List<Map<String, String>> _categories = [
    {'key': 'crop_disease', 'label_en': 'Crop Disease', 'label_hi': 'फसल रोग', 'icon': '🌾'},
    {'key': 'mandi_bhav', 'label_en': 'Mandi Bhav', 'label_hi': 'मंडी भाव', 'icon': '📈'},
    {'key': 'mausam', 'label_en': 'Weather', 'label_hi': 'मौसम', 'icon': '🌦️'},
    {'key': 'govt_schemes', 'label_en': 'Govt Schemes', 'label_hi': 'सरकारी योजनाएं', 'icon': '📜'},
    {'key': 'other', 'label_en': 'Other', 'label_hi': 'अन्य', 'icon': '⚙️'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  String _getCategoryLabel(String key, Map<String, String> t) {
    final cat = _categories.firstWhere((c) => c['key'] == key, orElse: () => {'key': 'other', 'label_en': 'Other', 'label_hi': 'अन्य'});
    final isHindi = t['welcome']?.contains('स्वागत') ?? false;
    return isHindi ? cat['label_hi']! : cat['label_en']!;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 800,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  void _showImagePickerOptions() {
    final t = ref.read(translationsProvider);
    final isHindi = t['welcome']?.contains('स्वागत') ?? false;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryColor),
                title: Text(isHindi ? 'कैमरा से फोटो लें' : 'Take Photo from Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppTheme.primaryColor),
                title: Text(isHindi ? 'गैलरी से चुनें' : 'Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _startVoiceDictation() {
    final t = ref.read(translationsProvider);
    final isHindi = t['welcome']?.contains('स्वागत') ?? false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _VoiceDictationDialog(
        isHindi: isHindi,
        onDictationComplete: (dictatedText) {
          setState(() {
            _questionController.text = dictatedText;
          });
        },
      ),
    );
  }

  Future<void> _submitQuestion() async {
    final t = ref.read(translationsProvider);
    final isHindi = t['welcome']?.contains('स्वागत') ?? false;

    if (_questionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isHindi
                ? 'कृपया अपना सवाल यहाँ लिखें!'
                : 'Please write your question first!',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final success = await ref.read(helplineNotifierProvider.notifier).submitQuestion(
          category: _selectedCategory,
          questionText: _questionController.text.trim(),
          imageFile: _selectedImage,
        );

    setState(() {
      _isSubmitting = false;
    });

    if (success) {
      _questionController.clear();
      setState(() {
        _selectedImage = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isHindi
                      ? 'आपका सवाल सफलतापूर्वक भेजा गया! विशेषज्ञ जल्द ही जवाब देंगे।'
                      : 'Question submitted successfully! Experts will reply soon.',
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.accentColor,
          duration: const Duration(seconds: 4),
        ),
      );

      // Smoothly switch to My Questions tab
      _tabController.animateTo(1);
    } else {
      final errorState = ref.read(helplineNotifierProvider);
      String errMsg = errorState.maybeWhen(
        error: (error, _) => error.toString(),
        orElse: () => 'Unknown error occurred',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isHindi
                ? 'जमा करने में विफल: $errMsg'
                : 'Failed to submit: $errMsg',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final isHindi = t['welcome']?.contains('स्वागत') ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: Text(
          t['kisan_helpline'] ?? 'Kisan Helpline',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryColor,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 48,
              decoration: glassDecoration(
                blur: 20,
                opacity: 0.85,
                borderRadius: BorderRadius.circular(24),
              ).copyWith(
                color: Colors.grey.withOpacity(0.08),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.12), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppTheme.secondaryColor,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
                  tabs: [
                    Tab(text: t['ask_expert'] ?? 'Ask Expert'),
                    Tab(text: t['my_questions'] ?? 'My Questions'),
                    Tab(text: t['community_forum'] ?? 'Community'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAskTab(t, isHindi),
          _buildMyQuestionsTab(t, isHindi),
          _buildCommunityTab(t, isHindi),
        ],
      ),
    );
  }

  // ── Tab 1: Ask Expert / सवाल पूछें ──────────────────────────────────────────
  Widget _buildAskTab(Map<String, String> t, bool isHindi) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Elegant Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: glassDecoration(
              blur: 15,
              opacity: 0.9,
              borderRadius: BorderRadius.circular(20),
            ).copyWith(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.08),
                  AppTheme.secondaryContainer.withOpacity(0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: AppTheme.primaryColor,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHindi ? 'मुफ्त कृषि विशेषज्ञ सलाह' : 'Free Expert Agri Advice',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isHindi
                            ? 'फसल बीमारी, खाद या मौसम पर सीधा सवाल पूछें और फोटो भेजें।'
                            : 'Ask directly about crop disease, fertilizers, or weather.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Category Selector label
          Text(
            isHindi ? 'विषय चुनें / Choose Category' : 'Select Category',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 10),

          // Category scrolling chips
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, i) {
                final cat = _categories[i];
                final isSelected = _selectedCategory == cat['key'];
                final label = isHindi ? cat['label_hi']! : cat['label_en']!;

                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCategory = cat['key']!;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.primaryColor.withOpacity(0.18),
                          width: 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.24),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Text(cat['icon']!, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : AppTheme.secondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Text Field Card with Speech typing integration
          Text(
            isHindi ? 'अपना सवाल विस्तार से लिखें' : 'Write Question in Detail',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 10),

          Container(
            decoration: glassDecoration(
              blur: 10,
              opacity: 0.95,
              borderRadius: BorderRadius.circular(20),
            ).copyWith(
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.12), width: 1),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _questionController,
                  maxLines: 5,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: isHindi
                        ? 'जैसे: मेरी कपास की फसल में पत्तों पर लाल धब्बे आ रहे हैं, क्या छिड़काव करें?'
                        : 'e.g. Cotton crop leaves are getting red spots, what to spray?',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    contentPadding: const EdgeInsets.all(16),
                    border: InputBorder.none,
                  ),
                ),
                const Divider(height: 1),
                Container(
                  color: Colors.grey.withOpacity(0.04),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Voice simulated dictation button
                      IconButton(
                        onPressed: _startVoiceDictation,
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mic_rounded,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                        tooltip: isHindi ? 'बोलकर लिखें (Dictate)' : 'Voice Dictate',
                      ),
                      Text(
                        isHindi ? 'कृषि विशेषज्ञों से सीधी सहायता' : 'Agri Experts directly online',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Crop Photo Attachment Card
          Text(
            isHindi ? 'फसल का फोटो जोड़ें (वैकल्पिक)' : 'Attach Crop Photo (Optional)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 10),

          if (_selectedImage == null)
            InkWell(
              onTap: _showImagePickerOptions,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                height: 140,
                decoration: glassDecoration(
                  blur: 8,
                  opacity: 0.9,
                  borderRadius: BorderRadius.circular(20),
                ).copyWith(
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    style: BorderStyle.solid,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_photo_alternate_rounded,
                      size: 40,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isHindi ? 'कैमरा या गैलरी से फोटो अपलोड करें' : 'Upload photo from Camera / Gallery',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isHindi ? 'रोग की सही पहचान के लिए साफ फोटो लें' : 'Clear photo helps in accurate diagnosis',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    )
                  ],
                ),
              ),
            )
          else
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 2),
                    ),
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Floating clear button
                Positioned(
                  top: 10,
                  right: 10,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedImage = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 32),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitQuestion,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _isSubmitting
                    ? (isHindi ? 'भेजा जा रहा है...' : 'Submitting...')
                    : (isHindi ? 'विशेषज्ञ को सवाल भेजें' : 'Send to Agri Expert'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 4,
                shadowColor: AppTheme.primaryColor.withOpacity(0.35),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Tab 2: My Questions / मेरे सवाल ─────────────────────────────────────────
  Widget _buildMyQuestionsTab(Map<String, String> t, bool isHindi) {
    final questionsAsync = ref.watch(helplineQuestionsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(helplineQuestionsProvider);
      },
      color: AppTheme.primaryColor,
      child: questionsAsync.when(
        data: (questions) {
          if (questions.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.06),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.forum_outlined,
                        size: 64,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isHindi ? 'कोई सवाल नहीं मिला!' : 'No questions found!',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isHindi
                          ? 'आपने अभी तक कोई सवाल नहीं पूछा है। विशेषज्ञ से सवाल पूछने के लिए पहले टैब पर जाएं।'
                          : 'You haven\'t asked any questions yet. Go to the first tab to ask an expert.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.3),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => _tabController.animateTo(0),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(isHindi ? 'अभी सवाल पूछें' : 'Ask Question Now'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: questions.length,
            itemBuilder: (context, i) {
              final q = questions[i];
              return _PersonalQuestionCard(
                question: q,
                categoryLabel: _getCategoryLabel(q['category'] ?? 'other', t),
                isHindi: isHindi,
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
        error: (err, _) => Center(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  isHindi ? 'लोड करने में विफल रहा!' : 'Failed to load questions!',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
                const SizedBox(height: 8),
                Text(err.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(helplineQuestionsProvider),
                  child: Text(isHindi ? 'पुनः प्रयास करें' : 'Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Tab 3: Community Forum / किसान चौपाल ────────────────────────────────────
  Widget _buildCommunityTab(Map<String, String> t, bool isHindi) {
    final forumAsync = ref.watch(communityForumProvider);

    return Column(
      children: [
        // Horizontal filter chips
        Container(
          height: 60,
          color: Colors.white,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            children: [
              _buildForumFilterChip('All', isHindi ? 'सभी' : 'All'),
              ..._categories.map((cat) {
                final label = isHindi ? cat['label_hi']! : cat['label_en']!;
                return _buildForumFilterChip(cat['key']!, label);
              }),
            ],
          ),
        ),

        // Live Forum List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(communityForumProvider);
            },
            color: AppTheme.primaryColor,
            child: forumAsync.when(
              data: (forumItems) {
                // Filter locally by selected category
                final filtered = _selectedForumCategory == 'All'
                    ? forumItems
                    : forumItems.where((item) => item['category'] == _selectedForumCategory).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.06),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.search_off_rounded, size: 48, color: AppTheme.primaryColor),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isHindi ? 'कोई सवाल नहीं मिला!' : 'No Q&A found!',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isHindi
                                ? 'इस श्रेणी में वर्तमान में कोई सार्वजनिक प्रश्न उत्तर मौजूद नहीं हैं।'
                                : 'No public answered questions exist for this category yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final item = filtered[i];
                    final itemId = item['id'].toString();
                    final isLiked = _likedQuestions.contains(itemId);

                    return _ForumQuestionCard(
                      item: item,
                      categoryLabel: _getCategoryLabel(item['category'] ?? 'other', t),
                      isHindi: isHindi,
                      isLiked: isLiked,
                      onLikeTap: () {
                        setState(() {
                          if (isLiked) {
                            _likedQuestions.remove(itemId);
                          } else {
                            _likedQuestions.add(itemId);
                          }
                        });
                      },
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              ),
              error: (err, _) => Center(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 16),
                      Text(isHindi ? 'लोड करने में त्रुटि!' : 'Error Loading Forum!'),
                      Text(err.toString(), style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForumFilterChip(String key, String label) {
    final isSelected = _selectedForumCategory == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppTheme.primaryColor,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedForumCategory = key;
          });
        },
        selectedColor: AppTheme.primaryColor,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : AppTheme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        showCheckmark: false,
      ),
    );
  }
}

// ── Voice Dictation Simulation Dialog ────────────────────────────────────────
class _VoiceDictationDialog extends StatefulWidget {
  final bool isHindi;
  final ValueChanged<String> onDictationComplete;

  const _VoiceDictationDialog({
    required this.isHindi,
    required this.onDictationComplete,
  });

  @override
  State<_VoiceDictationDialog> createState() => _VoiceDictationDialogState();
}

class _VoiceDictationDialogState extends State<_VoiceDictationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  Timer? _dictationTimer;
  Timer? _animationTimer;
  int _secondsElapsed = 0;
  String _typedText = '';
  int _charIndex = 0;
  bool _isTypingDone = false;

  late final String _targetQuery;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _targetQuery = widget.isHindi
        ? 'सर, मेरी कपास की फसल में पत्तों पर लाल धब्बे आ रहे हैं और कुछ पौधे मुरझा रहे हैं, इसके लिए कौन सा कीटनाशक या दवा का उपयोग करूं?'
        : 'Sir, red spots are appearing on the leaves of my cotton crop and some plants are wilting. What pesticide or medicine should I use?';

    // Start timer for pulsating voice scale waves
    _animationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });

    // Start simulated character-by-character typing after a brief delay
    Future.delayed(const Duration(milliseconds: 800), () {
      _startSimulatedTyping();
    });
  }

  void _startSimulatedTyping() {
    const duration = Duration(milliseconds: 40);
    _dictationTimer = Timer.periodic(duration, (timer) {
      if (!mounted) return;

      if (_charIndex < _targetQuery.length) {
        setState(() {
          _typedText += _targetQuery[_charIndex];
          _charIndex++;
        });
      } else {
        setState(() {
          _isTypingDone = true;
        });
        _dictationTimer?.cancel();
        // Automatically close dialog after typing is complete
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            widget.onDictationComplete(_typedText);
            Navigator.pop(context);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _dictationTimer?.cancel();
    _animationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: glassDecoration(
          blur: 24,
          opacity: 0.96,
          borderRadius: BorderRadius.circular(28),
        ).copyWith(
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dictation Status Header
            Text(
              widget.isHindi ? 'बोलिए, हम सुन रहे हैं...' : 'Speak, we are listening...',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: AppTheme.primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              widget.isHindi ? 'कृषि प्रश्न की ऑटो-डिक्टेशन जारी है' : 'Auto-dictation of agri query in progress',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            // Pulsating Green Mic soundwave animation
            Stack(
              alignment: Alignment.center,
              children: [
                if (!_isTypingDone) ...[
                  // Outer Wave 2
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      final scale = 1.0 + (_animationController.value * 0.5);
                      final opacity = (1.0 - _animationController.value) * 0.35;
                      return Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(opacity),
                          shape: BoxShape.circle,
                        ),
                        transform: Matrix4.identity()..scale(scale),
                      );
                    },
                  ),
                  // Outer Wave 1
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      final scale = 1.0 + (_animationController.value * 0.25);
                      final opacity = (1.0 - _animationController.value) * 0.5;
                      return Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withOpacity(opacity),
                          shape: BoxShape.circle,
                        ),
                        transform: Matrix4.identity()..scale(scale),
                      );
                    },
                  ),
                ],
                // Center Mic Button
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Dictation Timer Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle, color: Colors.redAccent, size: 8),
                  const SizedBox(width: 6),
                  Text(
                    '00:${_secondsElapsed.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Simulated typed transcript container
            Container(
              width: double.infinity,
              height: 100,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.12)),
              ),
              child: SingleChildScrollView(
                reverse: true,
                child: Text(
                  _typedText.isEmpty
                      ? (widget.isHindi ? 'सुनना शुरू हो रहा है...' : 'Starting to listen...')
                      : '“ $_typedText ”',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryContainer,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Actions row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    widget.isHindi ? 'रद्द करें' : 'Cancel',
                    style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    widget.onDictationComplete(_typedText);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: Text(widget.isHindi ? 'हो गया' : 'Done'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

// ── Tab 2 Card: Personal Question Card ───────────────────────────────────────
class _PersonalQuestionCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> question;
  final String categoryLabel;
  final bool isHindi;

  const _PersonalQuestionCard({
    required this.question,
    required this.categoryLabel,
    required this.isHindi,
  });

  @override
  ConsumerState<_PersonalQuestionCard> createState() => _PersonalQuestionCardState();
}

class _PersonalQuestionCardState extends ConsumerState<_PersonalQuestionCard> {
  bool _isExpanded = false;

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: glassDecoration(
              blur: 20,
              opacity: 0.95,
              borderRadius: BorderRadius.circular(24),
            ).copyWith(
              border: Border.all(
                color: Colors.redAccent.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Red warning icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.redAccent.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                // Heading
                Text(
                  widget.isHindi ? 'सवाल हमेशा के लिए हटाएं?' : 'Delete Question Permanently?',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Bilingual warning texts
                Text(
                  widget.isHindi
                      ? 'क्या आप इस सवाल को स्थायी रूप से हटाना चाहते हैं? यह क्रिया वापस नहीं ली जा सकती।'
                      : 'Are you sure you want to permanently delete this question? This action cannot be undone.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                if (widget.isHindi)
                  Text(
                    'Are you sure you want to permanently delete this question? This action cannot be undone.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  )
                else
                  Text(
                    'क्या आप इस सवाल को स्थायी रूप से हटाना चाहते हैं? यह क्रिया वापस नहीं ली जा सकती।',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 24),
                // Actions (Cancel / Delete)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          widget.isHindi ? 'रद्द करें / Cancel' : 'Cancel',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _performDelete();
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          widget.isHindi ? 'हटाएं / Delete' : 'Delete',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _performDelete() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final isHindi = widget.isHindi;

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(isHindi ? 'सवाल हटाया जा रहा है...' : 'Deleting question...'),
        duration: const Duration(seconds: 1),
      ),
    );

    final success = await ref
        .read(helplineNotifierProvider.notifier)
        .deleteQuestion(widget.question['id'].toString());

    if (success) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            isHindi
                ? 'सवाल सफलतापूर्वक हटा दिया गया है।'
                : 'Question deleted successfully.',
          ),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    } else {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            isHindi
                ? 'हटाने में विफलता! कृपया पुनः प्रयास करें।'
                : 'Failed to delete question. Please try again.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.question['status'] ?? 'Pending';
    final isReplied = status == 'Replied';
    final isRejected = status == 'Rejected';
    final isResolved = isReplied || isRejected;
    final text = widget.question['question_text'] ?? '';
    final imageUrl = widget.question['image_url'];
    final answerText = widget.question['answer_text'];
    final timeStr = widget.question['created_at'] != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(widget.question['created_at']))
        : '';
    final repliedTimeStr = widget.question['replied_at'] != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(widget.question['replied_at']))
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isReplied
              ? AppTheme.accentColor.withOpacity(0.2)
              : isRejected
                  ? Colors.redAccent.withOpacity(0.2)
                  : Colors.amber.withOpacity(0.25),
          width: 1,
        ),
      ),
      color: Colors.white,
      elevation: 3,
      shadowColor: isReplied
          ? AppTheme.accentColor.withOpacity(0.06)
          : isRejected
              ? Colors.redAccent.withOpacity(0.06)
              : Colors.amber.withOpacity(0.06),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Card Header (Category, Date & Status Badge)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Category Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.categoryLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isReplied
                                  ? AppTheme.accentColor.withOpacity(0.12)
                                  : isRejected
                                      ? Colors.redAccent.withOpacity(0.12)
                                      : Colors.amber.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isReplied
                                  ? (widget.isHindi ? 'जवाब मिला' : 'Replied')
                                  : isRejected
                                      ? (widget.isHindi ? 'अस्वीकृत' : 'Rejected')
                                      : (widget.isHindi ? 'लंबित' : 'Pending'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isReplied
                                    ? AppTheme.accentColor
                                    : isRejected
                                        ? Colors.redAccent
                                        : Colors.amber[900],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Delete Icon / Trash button
                          InkWell(
                            onTap: () => _confirmDelete(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent.withOpacity(0.8),
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // User Question preview (Full if replied or expanded, otherwise 2 lines max)
                  Text(
                    text,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.primaryColor,
                    ),
                    maxLines: (isResolved || _isExpanded) ? null : 2,
                    overflow: (isResolved || _isExpanded) ? TextOverflow.visible : TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Image attachment preview if expanded, replied, or normal
                  if (imageUrl != null && imageUrl.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: (isResolved || _isExpanded) ? 180 : 100,
                        width: double.infinity,
                        color: Colors.grey.withOpacity(0.08),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey.withOpacity(0.1),
                            child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                      // View details / expand arrow only if not replied
                      if (!isResolved)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          child: Row(
                            children: [
                              Text(
                                _isExpanded
                                    ? (widget.isHindi ? 'कम दिखाएं' : 'Show Less')
                                    : (widget.isHindi ? 'पूरा देखें' : 'View Full'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              Icon(
                                _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                size: 16,
                                color: AppTheme.primaryColor,
                              ),
                            ],
                          ),
                        )
                    ],
                  ),
                ],
              ),
            ),

            // Expert Reply / Solution Section (Always visible if Replied or Rejected, or shown if expanded)
            if (isResolved || _isExpanded) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isReplied
                      ? AppTheme.primaryColor.withOpacity(0.04)
                      : isRejected
                          ? Colors.red.withOpacity(0.015)
                          : Colors.amber.withOpacity(0.03),
                  border: Border(
                    top: BorderSide(
                      color: isReplied
                          ? AppTheme.accentColor.withOpacity(0.12)
                          : isRejected
                              ? Colors.redAccent.withOpacity(0.12)
                              : Colors.amber.withOpacity(0.12),
                    ),
                  ),
                ),
                child: isReplied
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.psychology_rounded,
                                  color: AppTheme.primaryColor,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.isHindi
                                          ? 'डॉ. संजय वर्मा (वरिष्ठ कृषि वैज्ञानिक)'
                                          : 'Dr. Sanjay Verma (Agri Expert Specialist)',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    Text(
                                      widget.isHindi ? 'भारतफ्लो कृषि सलाहकार बोर्ड' : 'BharatFlow Advisory Panel',
                                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Expert Chat Bubble
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryContainer.withOpacity(0.65),
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
                            ),
                            child: Text(
                              answerText ?? '',
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: AppTheme.primaryColor,
                                height: 1.35,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              repliedTimeStr,
                              style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                            ),
                          )
                        ],
                      )
                    : isRejected
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.cancel_outlined,
                                      color: Colors.redAccent,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.isHindi
                                              ? 'कृषि विशेषज्ञ (सलाहकार अस्वीकरण)'
                                              : 'Agri Advisory Board (Ticket Rejected)',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                        Text(
                                          widget.isHindi ? 'अस्वीकृति विवरण / Rejection Details' : 'Rejection Reason Details',
                                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Rejection Chat Bubble
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50.withOpacity(0.6),
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                  border: Border.all(color: Colors.redAccent.withOpacity(0.1)),
                                ),
                                child: Text(
                                  answerText ?? (widget.isHindi ? 'यह सवाल निरस्त कर दिया गया है।' : 'This query has been rejected.'),
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: Colors.red[900],
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  repliedTimeStr,
                                  style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                                ),
                              )
                            ],
                          )
                        : Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        widget.isHindi
                                            ? 'कृषि विशेषज्ञ आपके सवाल की जांच कर रहे हैं। आपको जल्द ही उत्तर प्राप्त होगा (सामान्यतः 2-4 घंटे में)।'
                                            : 'Agri Experts are currently verifying crop details. You will receive a notification and answer soon.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange[900],
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
// ── Tab 3 Card: Community Forum Q&A Card ──────────────────────────────────────
class _ForumQuestionCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final String categoryLabel;
  final bool isHindi;
  final bool isLiked;
  final VoidCallback onLikeTap;

  const _ForumQuestionCard({
    required this.item,
    required this.categoryLabel,
    required this.isHindi,
    required this.isLiked,
    required this.onLikeTap,
  });

  @override
  State<_ForumQuestionCard> createState() => _ForumQuestionCardState();
}

class _ForumQuestionCardState extends State<_ForumQuestionCard> {
  int _helpfulCount = 0;

  @override
  void initState() {
    super.initState();
    // Simulate a dynamic baseline of helpful votes
    _helpfulCount = 5 + (widget.item['question_text'].toString().length % 20);
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.item['question_text'] ?? '';
    final imageUrl = widget.item['image_url'];
    final answerText = widget.item['answer_text'] ?? '';
    final city = widget.item['user_city'] ?? 'Surat';
    final state = widget.item['user_state'] ?? 'Gujarat';
    final repliedTimeStr = widget.item['replied_at'] != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(widget.item['replied_at']))
        : (widget.item['created_at'] != null
            ? DateFormat('dd MMM yyyy').format(DateTime.parse(widget.item['created_at']))
            : '');

    // Display anonymized sender
    final anonymizedSender = widget.isHindi
        ? 'गुप्त किसान (निवासी: $city, $state)'
        : 'Anonymous Kisan (from $city, $state)';

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.12), width: 1),
      ),
      color: Colors.white,
      elevation: 4,
      shadowColor: AppTheme.primaryColor.withOpacity(0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Anonymized Sender & Category Tag)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Sender Info
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_circle_outlined,
                        color: AppTheme.secondaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          anonymizedSender,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          repliedTimeStr,
                          style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
                // Category Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.categoryLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Question Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'सवाल: “ $text ”',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.primaryColor,
                height: 1.35,
              ),
            ),
          ),

          // Crop Photo (if any)
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey.withOpacity(0.08),
                      child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Answer Section (Green Container)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.secondaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.psychology_outlined,
                      color: AppTheme.primaryColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.isHindi
                          ? 'विशेषज्ञ का जवाब (Expert Response)'
                          : 'Expert Verified Answer',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  answerText,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[800],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Footer (Helpful button & Share option)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Helpful vote button
                InkWell(
                  onTap: () {
                    widget.onLikeTap();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: widget.isLiked
                          ? AppTheme.accentColor.withOpacity(0.12)
                          : Colors.grey.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.isLiked
                            ? AppTheme.accentColor.withOpacity(0.4)
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                          size: 14,
                          color: widget.isLiked ? AppTheme.accentColor : Colors.grey[700],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.isHindi
                              ? 'मददगार (${_helpfulCount + (widget.isLiked ? 1 : 0)})'
                              : 'Helpful (${_helpfulCount + (widget.isLiked ? 1 : 0)})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: widget.isLiked ? AppTheme.accentColor : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Share button
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          widget.isHindi
                              ? 'सलाह साझा की जा रही है...'
                              : 'Sharing advice...',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.share_outlined,
                    size: 20,
                    color: AppTheme.secondaryColor,
                  ),
                  tooltip: widget.isHindi ? 'सलाह साझा करें' : 'Share Q&A',
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

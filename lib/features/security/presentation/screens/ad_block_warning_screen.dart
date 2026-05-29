import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bharat_flow/core/services/ad_blocker_service.dart';

class AdBlockWarningScreen extends StatefulWidget {
  final VoidCallback onAdBlockerDisabled;

  const AdBlockWarningScreen({
    super.key,
    required this.onAdBlockerDisabled,
  });

  @override
  State<AdBlockWarningScreen> createState() => _AdBlockWarningScreenState();
}

class _AdBlockWarningScreenState extends State<AdBlockWarningScreen> with SingleTickerProviderStateMixin {
  bool _isEnglish = true;
  bool _isChecking = false;
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _runCheck() async {
    setState(() => _isChecking = true);
    
    // Simulate a brief premium loading delay for visual satisfaction
    await Future.delayed(const Duration(milliseconds: 1200));
    
    final active = await AdBlockerService.isAdBlockerOrPrivateDnsActive();
    
    if (mounted) {
      setState(() => _isChecking = false);
      if (!active) {
        // Disabled! Celebrate and unlock
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEnglish ? '🎉 Success! Ad blocker disabled.' : '🎉 बधाई हो! विज्ञापन अवरोधक बंद हो गया है।',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF1B5E20),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onAdBlockerDisabled();
      } else {
        // Still active, show feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEnglish 
                ? '⚠️ Ad blocker is still active. Please turn it off.' 
                : '⚠️ विज्ञापन अवरोधक अभी भी चालू है। कृपया इसे बंद करें।',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFFC62828),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Beautiful Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF002411), // Extra deep forest green
                  Color(0xFF07120B), // Near black emerald
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          
          // Decorative glowing circles
          Positioned(
            top: -100,
            right: -50,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1B5E20).withOpacity(0.15),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFC62828).withOpacity(0.08),
                ),
              ),
            ),
          ),

          // 2. Language Toggle at Top-Right
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: InkWell(
                  onTap: () => setState(() => _isEnglish = !_isEnglish),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.translate_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _isEnglish ? 'हिन्दी (IN)' : 'English (EN)',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Central Glassmorphic Content Card
          Center(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Animated Glowing Protection / Warning Shield
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFC62828).withOpacity(0.2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFC62828).withOpacity(0.4),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      )
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.shield_outlined,
                                  size: 54,
                                  color: Color(0xFFFF5252),
                                ),
                                const Positioned(
                                  bottom: 12,
                                  child: Icon(
                                    Icons.block_flipped,
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Heading
                          Text(
                            _isEnglish ? 'Ad Blocker / DNS Detected' : 'विज्ञापन अवरोधक (Ad Blocker) चालू है',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Description
                          Text(
                            _isEnglish
                                ? 'BharatFlow provides high-quality services (Mandi prices, Weather, AI Advisory, News) completely free to all Indian citizens. We rely on minor ads to pay for servers. Please disable Private DNS (dns.adguard.com) or your ad blocker to continue.'
                                : 'भारतफ्लो भारत के सभी नागरिकों को मंडी भाव, मौसम, एआई सलाह और समाचार जैसी सभी सुविधाएं पूरी तरह से मुफ्त प्रदान करता है। सर्वर खर्च के लिए हम छोटे विज्ञापनों पर निर्भर हैं। कृपया आगे बढ़ने के लिए प्राइवेट डीएनएस (dns.adguard.com) या विज्ञापन अवरोधक बंद करें।',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.7),
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 16),

                          // Step-by-step guidance
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _isEnglish ? 'How to disable it:' : 'इसे कैसे बंद करें:',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Steps list
                          _buildStepRow(
                            '1',
                            _isEnglish 
                              ? 'Open your Phone Settings.' 
                              : 'अपने फोन की सेटिंग्स खोलें।',
                          ),
                          const SizedBox(height: 8),
                          _buildStepRow(
                            '2',
                            _isEnglish
                              ? 'Go to Network & Internet ➔ Private DNS.'
                              : 'नेटवर्क और इंटरनेट ➔ प्राइवेट डीएनएस (Private DNS) पर जाएं।',
                          ),
                          const SizedBox(height: 8),
                          _buildStepRow(
                            '3',
                            _isEnglish
                              ? 'Set Private DNS to "OFF" or "Automatic".'
                              : 'प्राइवेट डीएनएस को "बंद (OFF)" या "स्वचालित (Auto)" पर सेट करें।',
                          ),
                          const SizedBox(height: 8),
                          _buildStepRow(
                            '4',
                            _isEnglish
                              ? 'Or turn off any ad-blockers (AdGuard app, etc.).'
                              : 'या किसी भी विज्ञापन अवरोधक ऐप (AdGuard आदि) को बंद करें।',
                          ),

                          const SizedBox(height: 28),

                          // 4. Action Buttons
                          if (_isChecking)
                            Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF81C784)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _isEnglish ? 'Checking network...' : 'नेटवर्क की जांच हो रही है...',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                            )
                          else ...[
                            // Button 1: Settings Link (Android only)
                            ElevatedButton(
                              onPressed: () async {
                                await AdBlockerService.openPrivateDnsSettings();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1B5E20),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.settings_suggest_outlined, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isEnglish ? 'Change Settings' : 'सेटिंग्स बदलें',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Button 2: Check Again
                            OutlinedButton(
                              onPressed: _runCheck,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1.5),
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.refresh_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isEnglish ? 'Check Again' : 'फिर से जांचें',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),
                          
                          // Autotrack info footer
                          Text(
                            _isEnglish 
                              ? 'App will auto-unlock once ad blocker is disabled.' 
                              : 'विज्ञापन अवरोधक बंद होने पर ऐप अपने आप खुल जाएगा।',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.4),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1B5E20).withOpacity(0.2),
            border: Border.all(color: const Color(0xFF81C784).withOpacity(0.4), width: 1),
          ),
          child: Text(
            number,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF81C784),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: Colors.white.withOpacity(0.85),
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

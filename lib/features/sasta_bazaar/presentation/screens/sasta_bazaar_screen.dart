import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bharat_flow/core/providers/settings_provider.dart';
import 'package:bharat_flow/core/widgets/translated_text.dart';
import '../../data/sasta_bazaar_repository.dart';
import '../widgets/amazon_affiliate_banner.dart';

class SastaBazaarScreen extends ConsumerStatefulWidget {
  const SastaBazaarScreen({super.key});

  @override
  ConsumerState<SastaBazaarScreen> createState() => _SastaBazaarScreenState();
}

class _SastaBazaarScreenState extends ConsumerState<SastaBazaarScreen> {
  String _searchQuery = '';

  Future<void> _launchMaps(double lat, double lng) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchCall(String phone) async {
    final url = 'tel:$phone';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mandalisAsync = ref.watch(sastaBazaarProvider);
    final totalCountAsync = ref.watch(totalMandalisCountProvider);
    final t = ref.watch(translationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9), // Slightly darker green
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8F5E9), // Slightly darker green
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F3D2F)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(t['sasta_bazaar'] ?? 'Sasta Bazaar', style: const TextStyle(color: Color(0xFF0F3D2F), fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  icon: const Icon(Icons.search, color: Colors.black45),
                  border: InputBorder.none,
                  hintText: t['search_mandali'] ?? 'Search Mandali...',
                  hintStyle: const TextStyle(color: Colors.black38, fontSize: 15),
                  suffixIconConstraints: const BoxConstraints(maxHeight: 32),
                  suffixIcon: totalCountAsync.when(
                    data: (count) => Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F4EA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count+ ' + (t['mandalis'] ?? 'MANDALIS'),
                        style: const TextStyle(
                          color: Color(0xFF1E8E3E),
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),

          // List View
          Expanded(
            child: mandalisAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0F3D2F))),
              error: (err, stack) => Center(child: Text((t['error_loading_mandalis'] ?? 'Error loading mandalis: ') + err.toString())),
              data: (mandalis) {
                // Filter by search query
                final filtered = mandalis.where((m) {
                  return m.name.toLowerCase().contains(_searchQuery) ||
                         m.address.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(child: Text(t['no_cooperatives_found'] ?? 'No cooperative societies found in this area.', style: const TextStyle(color: Colors.black54)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final mandali = filtered[index];
                    return _buildMandaliCard(mandali, t);
                  },
                );
              },
            ),
          ),

          // Amazon Affiliate Banner (Bottom)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: AmazonAffiliateBanner(),
          ),
        ],
      ),
    );
  }

  Widget _buildMandaliCard(Mandali mandali, Map<String, String> t) {
    final statusColor = mandali.isOpen ? const Color(0xFF1E8E3E) : const Color(0xFFD64A20);
    final statusText = mandali.isOpen ? (t['open_now'] ?? 'Open Now') : (t['closed'] ?? 'Closed');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Distance
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TranslatedText(
                  mandali.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF2D3748)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F3D2F).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${mandali.distanceKm.toStringAsFixed(1)} ' + (t['km_away'] ?? 'km away'),
                  style: const TextStyle(color: Color(0xFF0F3D2F), fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 14, color: Colors.black45),
              const SizedBox(width: 4),
              Expanded(
                child: TranslatedText(
                  mandali.address,
                  style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Timing & Status
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor)),
              const SizedBox(width: 6),
              Text(
                '$statusText (${mandali.openingTime} - ${mandali.closingTime})',
                style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _launchMaps(mandali.lat, mandali.lng),
                  icon: const Icon(Icons.directions, size: 18),
                  label: Text(t['get_directions'] ?? 'Get Directions', style: const TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F3D2F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (mandali.phone != null && mandali.phone!.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchCall(mandali.phone!),
                    icon: const Icon(Icons.call, size: 18),
                    label: Text(t['call_center'] ?? 'Call Center', style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F3D2F),
                      side: const BorderSide(color: Color(0xFF0F3D2F), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/leader_model.dart';
import '../widgets/comments_widget.dart';

class LeaderDetailScreen extends StatefulWidget {
  final LeaderModel leader;
  
  const LeaderDetailScreen({super.key, required this.leader});

  @override
  State<LeaderDetailScreen> createState() => _LeaderDetailScreenState();
}

class _LeaderDetailScreenState extends State<LeaderDetailScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;

  Future<void> _shareReportCard() async {
    setState(() => _isSharing = true);
    try {
      final image = await _screenshotController.capture(delay: const Duration(milliseconds: 10));
      if (image != null) {
        final directory = await getApplicationDocumentsDirectory();
        final imagePath = await File('${directory.path}/${widget.leader.name}_report.png').create();
        await imagePath.writeAsBytes(image);
        
        await Share.shareXFiles(
          [XFile(imagePath.path)], 
          text: 'Check out the real Neta Kundali of ${widget.leader.name} on Janta Ki Awaaz! \n#BharatFlow',
        );
      }
    } catch (e) {
      debugPrint('Share error: $e');
    }
    setState(() => _isSharing = false);
  }

  @override
  Widget build(BuildContext context) {
    final leader = widget.leader;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F1),
      appBar: AppBar(
        title: Text(leader.name, style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSharing ? null : _shareReportCard,
        backgroundColor: Colors.green.shade600,
        icon: _isSharing ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.share, color: Colors.white),
        label: const Text('Share Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Screenshot(
        controller: _screenshotController,
        child: Container(
          color: const Color(0xFFF1F5F1), // Need solid background for screenshot
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Profile
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: leader.photoUrl != null ? NetworkImage(leader.photoUrl!) : null,
                    child: leader.photoUrl == null ? const Icon(Icons.person, size: 50) : null,
                  ),
                ),
                const SizedBox(height: 16),
                Text(leader.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text('${leader.party} • ${leader.constituency}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
                
                const SizedBox(height: 24),
                
                const Center(
                  child: Text(
                    'NETA KUNDALI (Official Affidavit)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    if (leader.assets != null && leader.assets!.isNotEmpty)
                      SizedBox(width: (MediaQuery.of(context).size.width - 48) / 2, child: _buildInfoCard('Total Assets', '₹${leader.assets?['total'] ?? 'Unknown'}', Icons.account_balance_wallet, Colors.green)),
                    if (leader.liabilities != null && leader.liabilities!.isNotEmpty)
                      SizedBox(width: (MediaQuery.of(context).size.width - 48) / 2, child: _buildInfoCard('Liabilities', '₹${leader.liabilities?['total'] ?? 'Unknown'}', Icons.credit_card, Colors.red)),
                    if (leader.education != null && leader.education!.isNotEmpty && leader.education != 'N/A')
                      SizedBox(width: (MediaQuery.of(context).size.width - 48) / 2, child: _buildInfoCard('Education', leader.education!, Icons.school, Colors.blue)),
                    if (leader.criminalCases != null)
                      SizedBox(width: (MediaQuery.of(context).size.width - 48) / 2, child: _buildInfoCard('Criminal Cases', '${leader.criminalCases}', Icons.gavel, leader.criminalCases > 0 ? Colors.red : Colors.green)),
                    if (leader.birthdate != null && leader.birthdate!.isNotEmpty)
                      SizedBox(width: (MediaQuery.of(context).size.width - 48) / 2, child: _buildInfoCard('Birthdate', leader.birthdate!, Icons.cake, Colors.orange)),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Wikipedia Description
                if (leader.description != null && leader.description!.isNotEmpty) ...[
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      backgroundColor: Colors.white,
                      collapsedBackgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      collapsedShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      title: const Text('About Leader', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20))),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                          child: Text(leader.description!, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Detailed Breakdown List
                if (leader.assets != null && leader.assets!.containsKey('details')) ...[
                  const Text('Asset Breakdown', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20))),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                    child: Text('${leader.assets!['details']}'),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Data Source Disclaimer
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    backgroundColor: Colors.grey.shade100,
                    collapsedBackgroundColor: Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    collapsedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    title: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text('Data Source & Disclaimer', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800, fontSize: 14)),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                        child: Text(
                          '• Source: Information is aggregated from officially filed ECI Affidavits, MyNeta.info, and Wikipedia.\n'
                          '• N/A Fields: Any missing financial or educational data means it hasn\'t been published or processed yet.\n'
                          '• Liability: This app is an independent platform for public awareness. Developers are not affiliated with any government entity and do not take legal responsibility for absolute accuracy.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                CommentsWidget(leaderId: leader.id),
                const SizedBox(height: 80), // Padding for FAB
                
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ]
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

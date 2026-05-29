import 'package:flutter/material.dart';
import '../../data/models/leader_model.dart';

class LeaderDetailScreen extends StatelessWidget {
  final LeaderModel leader;
  
  const LeaderDetailScreen({super.key, required this.leader});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F1),
      appBar: AppBar(
        title: Text(leader.name, style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
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
            
            const Text(
              'NETA KUNDALI (Official Affidavit)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
                fontSize: 14,
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
              const Text('About Leader', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20))),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                child: Text(leader.description!, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87)),
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text('Data Source & Disclaimer', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Source: Information is aggregated from officially filed ECI Affidavits, MyNeta.info, and Wikipedia.\n'
                    '• N/A Fields: Any missing financial or educational data means it hasn\'t been published or processed yet.\n'
                    '• Liability: This app is an independent platform for public awareness. Developers are not affiliated with any government entity and do not take legal responsibility for absolute accuracy.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
          ],
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

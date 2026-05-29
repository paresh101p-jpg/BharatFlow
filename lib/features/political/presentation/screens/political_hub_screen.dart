import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/leader_model.dart';
import 'leader_detail_screen.dart';
import 'package:bharat_flow/core/providers/location_provider.dart';

class PoliticalHubScreen extends ConsumerStatefulWidget {
  const PoliticalHubScreen({super.key});

  @override
  ConsumerState<PoliticalHubScreen> createState() => _PoliticalHubScreenState();
}

class _PoliticalHubScreenState extends ConsumerState<PoliticalHubScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  List<LeaderModel> _leaders = [];
  bool _isLoading = true;
  String _searchQuery = '';

  RealtimeChannel? _realtimeChannel;

  int _currentTabIndex = 0; // 0: All Leaders, 1: My Votes, 2: Election Calendar
  int _totalLeadersCount = 0;
  List<Map<String, dynamic>> _elections = [];

  @override
  void initState() {
    super.initState();
    _fetchTotalLeadersCount();
    _fetchLocalLeaders();
    _fetchElections();
    _setupRealtime();
  }

  Future<void> _fetchElections() async {
    try {
      final response = await _supabase.from('election_calendar').select().order('id', ascending: true);
      if (mounted) {
        setState(() {
          _elections = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Error fetching elections: $e');
    }
  }

  Future<void> _fetchTotalLeadersCount() async {
    try {
      // In Supabase, fetching all ids to get length is a simple fallback if count API is tricky, 
      // but limit 1 with exact count is better.
      final response = await _supabase.from('leaders_master').select('id');
      if (mounted) {
        setState(() {
          _totalLeadersCount = (response as List).length;
        });
      }
    } catch (e) {
      debugPrint('Count error: $e');
    }
  }

  void _setupRealtime() {
    _realtimeChannel = _supabase
        .channel('public:leaders_master')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'leaders_master',
          callback: (payload) {
            final updatedLeaderId = payload.newRecord['id'];
            final updatedLikes = payload.newRecord['total_likes'];
            final updatedDislikes = payload.newRecord['total_dislikes'];

            if (mounted) {
              setState(() {
                final index = _leaders.indexWhere((l) => l.id == updatedLeaderId);
                if (index != -1) {
                  final oldLeader = _leaders[index];
                  _leaders[index] = LeaderModel(
                    id: oldLeader.id,
                    name: oldLeader.name,
                    party: oldLeader.party,
                    constituency: oldLeader.constituency,
                    photoUrl: oldLeader.photoUrl,
                    assets: oldLeader.assets,
                    liabilities: oldLeader.liabilities,
                    education: oldLeader.education,
                    criminalCases: oldLeader.criminalCases,
                    totalLikes: updatedLikes ?? oldLeader.totalLikes,
                    totalDislikes: updatedDislikes ?? oldLeader.totalDislikes,
                  );
                }
              });
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchLocalLeaders() async {
    setState(() => _isLoading = true);
    try {
      final loc = ref.read(locationProvider);
      final user = _supabase.auth.currentUser;
      
      if (_currentTabIndex == 1) { // My Votes
        if (user == null) {
          if (mounted) setState(() { _leaders = []; _isLoading = false; });
          return;
        }
        
        // Fetch leader IDs voted by this user
        final votesResponse = await _supabase.from('user_opinions').select('leader_id').eq('user_id', user.id);
        final votedLeaderIds = (votesResponse as List).map((v) => v['leader_id'] as String).toList();
        
        if (votedLeaderIds.isEmpty) {
          if (mounted) setState(() { _leaders = []; _isLoading = false; });
          return;
        }
        
        var query = _supabase.from('leaders_master').select().inFilter('id', votedLeaderIds);
        if (_searchQuery.isNotEmpty) {
          final formattedQuery = _searchQuery.trim().replaceAll(RegExp(r'\s+'), ' & ');
          query = query.textSearch('search_vector', "'$formattedQuery'");
        }
        final response = await query;
        if (mounted) {
          setState(() {
            _leaders = (response as List).map((e) => LeaderModel.fromJson(e)).toList();
            _isLoading = false;
          });
        }
        return;
      }
      // Normal fetch
      if (_searchQuery.isNotEmpty) {
        var query = _supabase.from('leaders_master').select();
        final formattedQuery = _searchQuery.trim().replaceAll(RegExp(r'\s+'), ' & ');
        query = query.textSearch('search_vector', "'$formattedQuery'");
        final response = await query.limit(50);
        
        if (mounted) {
          setState(() {
            _leaders = (response as List).map((e) => LeaderModel.fromJson(e)).toList();
            _isLoading = false;
          });
        }
      } else {
        // Fetch local leaders first directly from DB
        List<dynamic> combined = [];
        
        if (loc.city.isNotEmpty) {
          final localRes = await _supabase.from('leaders_master').select().ilike('constituency', '%${loc.city}%').limit(20);
          combined.addAll(localRes as List);
        }
        
        if (loc.state.isNotEmpty && combined.length < 30) {
          final stateRes = await _supabase.from('leaders_master').select().ilike('constituency', '%${loc.state}%').limit(30);
          for (var item in stateRes as List) {
            if (!combined.any((e) => e['id'] == item['id'])) combined.add(item);
          }
        }
        
        // Fill remaining up to 50
        if (combined.length < 50) {
          final restRes = await _supabase.from('leaders_master').select().limit(50 - combined.length);
          for (var item in restRes as List) {
            if (!combined.any((e) => e['id'] == item['id'])) combined.add(item);
          }
        }
        
        if (mounted) {
          setState(() {
            _leaders = combined.map((e) => LeaderModel.fromJson(e)).toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching leaders: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _castVote(String leaderId, String voteType) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to vote')),
        );
        return;
      }

      // First, check if the exact same vote already exists
      final existingVote = await _supabase
          .from('user_opinions')
          .select('vote')
          .eq('user_id', user.id)
          .eq('leader_id', leaderId)
          .maybeSingle();

      if (existingVote != null && existingVote['vote'] == voteType) {
        // User clicked the same vote button again, meaning they want to remove their vote
        await _supabase
            .from('user_opinions')
            .delete()
            .eq('user_id', user.id)
            .eq('leader_id', leaderId);
      } else {
        // Upsert the new user opinion (insert or change vote)
        await _supabase.from('user_opinions').upsert({
          'user_id': user.id,
          'leader_id': leaderId,
          'vote': voteType,
        }, onConflict: 'user_id,leader_id');
      }
      
      // The trigger should handle updating the counter. For now we just refresh.
      _fetchLocalLeaders();
      
    } on PostgrestException catch (e) {
      if (!mounted) return;
      if (e.message.contains('VOTE_LOCKED')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can only change your vote once every 7 days.'), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      }
    } catch (e) {
      debugPrint('Vote error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F1),
      appBar: AppBar(
        title: const Text('Janta Ki Awaaz', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Global Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: _totalLeadersCount > 0 ? 'Search among $_totalLeadersCount Leaders...' : 'Search Leader, Party, or City...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _fetchLocalLeaders();
                      },
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (val) {
                    setState(() => _searchQuery = val);
                    _fetchLocalLeaders();
                  },
                ),
                const SizedBox(height: 12),
                // Toggle between All and My Votes
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ToggleButtons(
                    borderRadius: BorderRadius.circular(8),
                    fillColor: const Color(0xFF1B5E20),
                    selectedColor: Colors.white,
                    color: Colors.grey.shade600,
                    constraints: const BoxConstraints(minHeight: 40),
                    isSelected: [_currentTabIndex == 0, _currentTabIndex == 1, _currentTabIndex == 2],
                    onPressed: (index) {
                      setState(() {
                        _currentTabIndex = index;
                      });
                      if (index < 2) _fetchLocalLeaders();
                    },
                    children: [
                      Container(
                        width: (MediaQuery.of(context).size.width - 36) / 3,
                        alignment: Alignment.center,
                        child: const Text('All Leaders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      Container(
                        width: (MediaQuery.of(context).size.width - 36) / 3,
                        alignment: Alignment.center,
                        child: const Text('My Votes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      Container(
                        width: (MediaQuery.of(context).size.width - 36) / 3,
                        alignment: Alignment.center,
                        child: const Text('Elections', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _currentTabIndex == 2
              ? _buildElectionCalendar()
              : _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _leaders.isEmpty
                  ? Center(child: Text(_currentTabIndex == 1 ? 'You haven\'t voted for any leaders yet.' : 'No leaders found.'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _leaders.length,
                      itemBuilder: (context, index) {
                        final leader = _leaders[index];
                        return _buildLeaderCard(leader);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildElectionCalendar() {
    if (_elections.isEmpty) {
      return const Center(child: Text('Loading Election Calendar...'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _elections.length,
      itemBuilder: (context, index) {
        final election = _elections[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))
            ]
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                child: Icon(Icons.how_to_vote, color: Colors.blue.shade700),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${election['state_name']} ${election['election_type']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('Date: ${election['expected_date']}', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(election['status'], style: TextStyle(color: Colors.orange.shade800, fontSize: 12, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeaderCard(LeaderModel leader) {
    // Calculate percentages
    final totalVotes = leader.totalLikes + leader.totalDislikes;
    final likePercent = totalVotes > 0 ? (leader.totalLikes / totalVotes) : 0.0;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => LeaderDetailScreen(leader: leader)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: (leader.photoUrl != null && leader.photoUrl!.isNotEmpty) ? NetworkImage(leader.photoUrl!) : null,
                  onBackgroundImageError: (exception, stackTrace) {
                    debugPrint('Image load failed for ${leader.name}');
                  },
                  child: (leader.photoUrl == null || leader.photoUrl!.isEmpty) 
                      ? const Icon(Icons.person, size: 30) 
                      : null, // If we want to show an icon on error, it's a bit tricky with CircleAvatar, we might need a custom widget or just let it be grey.
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(leader.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('${leader.party} • ${leader.constituency}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Live Status Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: likePercent,
                minHeight: 8,
                backgroundColor: Colors.red.shade400,
                color: Colors.green.shade500,
              ),
            ),
            const SizedBox(height: 12),
            
            // Vote Mechanism
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _castVote(leader.id, 'LIKE'),
                  icon: const Icon(Icons.thumb_up_rounded, color: Colors.green),
                  label: Text('${leader.totalLikes}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.green.shade200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const Text('VOTE NOW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                OutlinedButton.icon(
                  onPressed: () => _castVote(leader.id, 'DISLIKE'),
                  icon: const Icon(Icons.thumb_down_rounded, color: Colors.red),
                  label: Text('${leader.totalDislikes}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

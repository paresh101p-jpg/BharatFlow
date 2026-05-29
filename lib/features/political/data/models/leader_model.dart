class LeaderModel {
  final String id;
  final String name;
  final String party;
  final String constituency;
  final String? photoUrl;
  final Map<String, dynamic>? assets;
  final Map<String, dynamic>? liabilities;
  final String? education;
  final int criminalCases;
  final int totalLikes;
  final int totalDislikes;
  final String? description;
  final String? birthdate;

  LeaderModel({
    required this.id,
    required this.name,
    required this.party,
    required this.constituency,
    this.photoUrl,
    this.assets,
    this.liabilities,
    this.education,
    this.criminalCases = 0,
    this.totalLikes = 0,
    this.totalDislikes = 0,
    this.description,
    this.birthdate,
  });

  factory LeaderModel.fromJson(Map<String, dynamic> json) {
    return LeaderModel(
      id: json['id'] as String,
      name: json['name'] as String,
      party: json['party'] as String,
      constituency: json['constituency'] as String,
      photoUrl: json['photo_url'] as String?,
      assets: json['assets'] as Map<String, dynamic>?,
      liabilities: json['liabilities'] as Map<String, dynamic>?,
      education: json['education'] as String?,
      criminalCases: json['criminal_cases'] as int? ?? 0,
      totalLikes: json['total_likes'] as int? ?? 0,
      totalDislikes: json['total_dislikes'] as int? ?? 0,
      description: json['description'] as String?,
      birthdate: json['birthdate'] as String?,
    );
  }
}

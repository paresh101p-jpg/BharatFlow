class PartyModel {
  final String id;
  final String name;
  final String? logoUrl;
  final int totalLikes;

  PartyModel({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.totalLikes,
  });

  factory PartyModel.fromJson(Map<String, dynamic> json) {
    return PartyModel(
      id: json['id'] as String,
      name: json['name'] as String,
      logoUrl: json['logo_url'] as String?,
      totalLikes: json['total_likes'] as int? ?? 0,
    );
  }
}

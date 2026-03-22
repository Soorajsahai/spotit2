/// A post created by a user: image + description. Shown on home, my reports, and admin.
class Post {
  final String? key;
  final String imageUrl;
  final String description;
  final String authorId;
  final String authorName;
  final DateTime? createdAt;

  Post({
    this.key,
    required this.imageUrl,
    required this.description,
    required this.authorId,
    required this.authorName,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'imageUrl': imageUrl,
        'description': description,
        'authorId': authorId,
        'authorName': authorName,
        'createdAt': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      };

  static Post fromJson(Map<dynamic, dynamic> json, [String? key]) {
    final createdAtStr = json['createdAt']?.toString();
    return Post(
      key: key,
      imageUrl: json['imageUrl']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      authorId: json['authorId']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? 'Unknown',
      createdAt: createdAtStr != null ? DateTime.tryParse(createdAtStr) : null,
    );
  }
}

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

  // ─── Firebase legacy ──────────────────────────────────────────────────────
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

  // ─── Supabase ─────────────────────────────────────────────────────────────
  Map<String, dynamic> toSupabaseJson() => {
        'image_url': imageUrl,
        'description': description,
        'author_id': authorId,
        'author_name': authorName,
        'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      };

  static Post fromMap(Map<String, dynamic> map) {
    final createdAtStr = map['created_at']?.toString();
    return Post(
      key: map['id']?.toString(),
      imageUrl: map['image_url']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      authorId: map['author_id']?.toString() ?? '',
      authorName: map['author_name']?.toString() ?? 'Unknown',
      createdAt: createdAtStr != null ? DateTime.tryParse(createdAtStr) : null,
    );
  }
}

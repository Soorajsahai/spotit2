class Issue {
  final String title;
  final String className;
  final String severity;
  final double confidence;
  final double latitude;
  final double longitude;
  final String status;
  final String? imageBase64; // Legacy field for backward compatibility
  final String? imageUrl; // Firebase Storage URL (original/taken image for home feed)
  final String? detectedImageUrl; // AI-detected/annotated image for admin
  final DateTime? reportedAt;
  final int upvotes;
  final int downvotes;
  final Map<String, int> votes;
  final String? reportedBy; // user id of reporter

  Issue({
    required this.title,
    required this.className,
    required this.severity,
    required this.confidence,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.imageBase64,
    this.imageUrl,
    this.detectedImageUrl,
    this.reportedAt,
    this.upvotes = 0,
    this.downvotes = 0,
    Map<String, int>? votes,
    this.reportedBy,
  }) : votes = votes ?? {};

  Map<String, dynamic> toJson() => {
        "title": title,
        "class": className,
        "severity": severity,
        "confidence": confidence,
        "latitude": latitude,
        "longitude": longitude,
        "status": status,
        "imageBase64": imageBase64 ?? '', // Keep for backward compatibility
        "imageUrl": imageUrl ?? '',
        "detectedImageUrl": detectedImageUrl ?? '',
        "upvotes": upvotes,
        "downvotes": downvotes,
        "votes": votes,
        "reportedBy": reportedBy ?? '',
        // include reportedAt as ISO8601 string; fall back to now
        "reportedAt": (reportedAt ?? DateTime.now()).toIso8601String(),
        // legacy key
        "timestamp": (reportedAt ?? DateTime.now()).toIso8601String(),
      };

  factory Issue.fromJson(Map<dynamic, dynamic> json) {
    DateTime? parsedReportedAt;
    final rawDate = json['reportedAt'] ?? json['timestamp'];
    if (rawDate != null) {
      try {
        parsedReportedAt = DateTime.tryParse(rawDate.toString());
      } catch (_) {
        parsedReportedAt = null;
      }
    }

    return Issue(
      title: (json['title'] ?? '') as String,
      className: (json['class'] ?? '') as String,
      severity: (json['severity'] ?? '') as String,
      confidence: (json['confidence'] is num)
          ? (json['confidence'] as num).toDouble()
          : double.tryParse('${json['confidence']}') ?? 0.0,
      latitude: (json['latitude'] is num)
          ? (json['latitude'] as num).toDouble()
          : double.tryParse('${json['latitude']}') ?? 0.0,
      longitude: (json['longitude'] is num)
          ? (json['longitude'] as num).toDouble()
          : double.tryParse('${json['longitude']}') ?? 0.0,
      status: (json['status'] ?? '') as String,
      imageBase64: json['imageBase64']?.toString().isEmpty == true ? null : json['imageBase64']?.toString(),
      imageUrl: json['imageUrl']?.toString().isEmpty == true ? null : json['imageUrl']?.toString(),
      detectedImageUrl: json['detectedImageUrl']?.toString().isEmpty == true ? null : json['detectedImageUrl']?.toString(),
      reportedAt: parsedReportedAt,
      upvotes: (json['upvotes'] is num) ? (json['upvotes'] as num).toInt() : int.tryParse('${json['upvotes']}') ?? 0,
      downvotes: (json['downvotes'] is num) ? (json['downvotes'] as num).toInt() : int.tryParse('${json['downvotes']}') ?? 0,
      votes: (json['votes'] is Map)
          ? Map<String, int>.fromEntries((json['votes'] as Map).entries.map((e) => MapEntry(e.key.toString(), (e.value is num) ? (e.value as num).toInt() : int.tryParse('${e.value}') ?? 0)))
          : {},
      reportedBy: (json['reportedBy'] ?? json['reported_by'] ?? '') == '' ? null : (json['reportedBy'] ?? json['reported_by']).toString(),
    );
  }
}

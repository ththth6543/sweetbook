class TravelLog {
  final int? id;
  final String title;
  final String location;
  final String content;
  final DateTime? createdAt;

  TravelLog({
    this.id,
    required this.title,
    required this.location,
    required this.content,
    this.createdAt,
  });

  factory TravelLog.fromJson(Map<String, dynamic> json) {
    return TravelLog(
      id: json['id'],
      title: json['title'],
      location: json['location'],
      content: json['content'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'location': location,
      'content': content,
    };
  }
}

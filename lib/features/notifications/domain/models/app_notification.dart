class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.payload,
    required this.isRead,
    required this.sentPush,
    this.productId,
    this.pushError,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final String? productId;
  final Map<String, dynamic> payload;
  final bool isRead;
  final bool sentPush;
  final String? pushError;
  final DateTime createdAt;
  final DateTime? readAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final payloadRaw = json['payload'];
    final payloadMap = payloadRaw is Map
        ? Map<String, dynamic>.from(payloadRaw)
        : <String, dynamic>{};

    return AppNotification(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'recommendation',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      productId: json['product_id']?.toString(),
      payload: payloadMap,
      isRead: json['is_read'] == true,
      sentPush: json['sent_push'] == true,
      pushError: json['push_error']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'].toString())
          : null,
    );
  }
}

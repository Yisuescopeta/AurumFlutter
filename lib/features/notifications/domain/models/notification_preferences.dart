class NotificationPreferences {
  const NotificationPreferences({
    required this.enabled,
    required this.favoriteDiscountEnabled,
    required this.recommendationsEnabled,
    required this.timezone,
    this.quietHoursStart,
    this.quietHoursEnd,
  });

  final bool enabled;
  final bool favoriteDiscountEnabled;
  final bool recommendationsEnabled;
  final String timezone;
  final String? quietHoursStart;
  final String? quietHoursEnd;

  factory NotificationPreferences.defaults() {
    return const NotificationPreferences(
      enabled: true,
      favoriteDiscountEnabled: true,
      recommendationsEnabled: true,
      timezone: 'Europe/Madrid',
      quietHoursStart: null,
      quietHoursEnd: null,
    );
  }

  NotificationPreferences copyWith({
    bool? enabled,
    bool? favoriteDiscountEnabled,
    bool? recommendationsEnabled,
    String? timezone,
    String? quietHoursStart,
    String? quietHoursEnd,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      favoriteDiscountEnabled:
          favoriteDiscountEnabled ?? this.favoriteDiscountEnabled,
      recommendationsEnabled:
          recommendationsEnabled ?? this.recommendationsEnabled,
      timezone: timezone ?? this.timezone,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'favorite_discount_enabled': favoriteDiscountEnabled,
      'recommendations_enabled': recommendationsEnabled,
      'timezone': timezone,
      'quiet_hours_start': quietHoursStart,
      'quiet_hours_end': quietHoursEnd,
    };
  }

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      enabled: json['enabled'] != false,
      favoriteDiscountEnabled: json['favorite_discount_enabled'] != false,
      recommendationsEnabled: json['recommendations_enabled'] != false,
      timezone: json['timezone']?.toString() ?? 'Europe/Madrid',
      quietHoursStart: json['quiet_hours_start']?.toString(),
      quietHoursEnd: json['quiet_hours_end']?.toString(),
    );
  }
}

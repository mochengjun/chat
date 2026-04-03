import '../../domain/entities/member.dart';

class MemberModel extends Member {
  const MemberModel({
    required super.userId,
    required super.displayName,
    super.avatarUrl,
    super.role,
    required super.joinedAt,
    super.isOnline,
  });

  /// 安全解析日期字符串，失败时返回 DateTime.now()
  static DateTime _safeParseDate(dynamic dateStr) {
    if (dateStr == null) return DateTime.now();
    final parsed = DateTime.tryParse(dateStr.toString());
    return parsed ?? DateTime.now();
  }

  factory MemberModel.fromJson(Map<String, dynamic> json) {
    return MemberModel(
      userId: json['user_id'],
      displayName: json['display_name'] ?? json['username'] ?? '',
      avatarUrl: json['avatar_url'],
      role: _parseRole(json['role']),
      joinedAt: _safeParseDate(json['joined_at']),
      isOnline: json['is_online'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'role': role.name,
      'joined_at': joinedAt.toIso8601String(),
      'is_online': isOnline,
    };
  }

  static MemberRole _parseRole(String? role) {
    switch (role) {
      case 'owner':
        return MemberRole.owner;
      case 'admin':
        return MemberRole.admin;
      case 'moderator':
        return MemberRole.moderator;
      default:
        return MemberRole.member;
    }
  }

  Member toEntity() => Member(
        userId: userId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        role: role,
        joinedAt: joinedAt,
        isOnline: isOnline,
      );
}

import 'user_model.dart';

class AuthResponse {
  final String? token;
  final UserModel? user;
  final String? message;
  final bool success;

  AuthResponse({
    this.token,
    this.user,
    this.message,
    this.success = false,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String?,
      user: json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      message: json['message'] as String?,
      success: json['success'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'user': user?.toJson(),
      'message': message,
      'success': success,
    };
  }
}


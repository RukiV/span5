class AuthConfig {
  static const String clientId = "ee909cd4-2fae-4cd2-8d7e-da7e8508d772";
  static const String tenantId = "DEFAULT"; // "common" allows any Microsoft account
  static const String redirectUri = "msauth://com.example.untitled/xc13Rb9XZfaL0EqEJWzx78ijaeM%3D"; // The msauth:// one

  // Scopes define what data we want to access.
  // 'openid', 'profile', and 'User.Read' are the basics for login.
  static const List<String> scopes = ["openid", "profile", "User.Read"];
}
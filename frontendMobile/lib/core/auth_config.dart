// AuthConfig: Static configuration for Microsoft Azure AD OAuth integration.
class AuthConfig {
  // CLIENT ID: Uniquely identifies our mobile app in the Azure Portal.
  static const String clientId = "ee909cd4-2fae-4cd2-8d7e-da7e8508d772";
  
  // TENANT: Set to "common" for any Microsoft account or a specific ID for Akademia.
  static const String tenantId = "DEFAULT"; 
  
  // REDIRECT URI: The URI Azure calls back to after a successful login.
  static const String redirectUri = "msauth://com.example.untitled/xc13Rb9XZfaL0EqEJWzx78ijaeM%3D";

  // SCOPES: Permissions we are requesting from the user.
  static const List<String> scopes = ["openid", "profile", "User.Read"];
  
  // FUTURE IDEA: Move these to a .env file to avoid hardcoding sensitive IDs.
}

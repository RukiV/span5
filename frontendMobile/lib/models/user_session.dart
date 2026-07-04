enum UserRole { admin, manager, student, contractor }

class UserSession {
  static int userId = 1; // By verstek, sal opgedateer word tydens login
  static UserRole role = UserRole.student;
  static String userName = "Simeon";
  static String userEmail = "";
  static String userCampus = "Hoofkampus (Centurion)";

  static bool get isAdmin => role == UserRole.admin;
  static bool get isManager => role == UserRole.manager;
  static bool get isStudent => role == UserRole.student;
  static bool get isContractor => role == UserRole.contractor;
  
  static bool get hasAdminPrivileges => role == UserRole.admin || role == UserRole.manager;
}

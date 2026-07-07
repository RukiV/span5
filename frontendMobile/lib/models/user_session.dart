/// UserRole: 'n Sterk-tipe enumerasie vir gebruikersrolle.
/// Dit verhoed foute wat deur "magic strings" of rou ID's veroorsaak word.
enum UserRole { admin, manager, student, contractor }

/// UserSession: 'n Globale, in-geheue stoorplek vir die huidige sessie.
/// Hierdie klas is verantwoordelik vir die bestuur van die gebruiker se staat
/// gedurende die leeftyd van die app.
class UserSession {
  static int userId = 0;
  static UserRole role = UserRole.student;
  static String userName = "";
  static String userEmail = "";
  static String userCampus = "Hoofkampus (Centurion)";

  /// Helper-metode om rou data vanaf die API te verwerk.
  /// Dit sentraliseer die logika vir roldoewysing.
  static void initialize(Map<String, dynamic> data) {
    userId = data['user_id'] ?? 0;
    userName = "${data['user_name'] ?? ''} ${data['user_surname'] ?? ''}".trim();
    userEmail = data['user_email'] ?? "";
    
    // Roldoewysing gebaseer op ID vanaf die backend.
    // 3 = Admin, 2 = Manager (FK), 1 = Student, 4 = Contractor.
    final int roleId = data['role_id'] ?? 1;
    switch (roleId) {
      case 3:
        role = UserRole.admin;
        break;
      case 2:
        role = UserRole.manager;
        break;
      case 4:
        role = UserRole.contractor;
        break;
      default:
        role = UserRole.student;
    }
  }

  // Gerieflike getters vir vinnige toegangsbeheer in die UI.
  static bool get isAdmin => role == UserRole.admin;
  static bool get isManager => role == UserRole.manager;
  static bool get isStudent => role == UserRole.student;
  static bool get isContractor => role == UserRole.contractor;
  
  /// Bepaal of die gebruiker administratiewe aksies mag uitvoer.
  static bool get hasAdminPrivileges => role == UserRole.admin || role == UserRole.manager;

  /// Maak die sessie skoon tydens logout.
  static void clear() {
    userId = 0;
    role = UserRole.student;
    userName = "";
    userEmail = "";
  }
}

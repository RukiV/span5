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
  static String userCampus = "";
  static int? locationId;

  /// Die gebruiker se regte (vanaf /auth/me se `rights`-lys). Dit is die enkele
  /// bron van waarheid vir toegangsbeheer — die [UserRole] enum word slegs vir
  /// vertoon (bv. [role] se titel) gebruik, nooit meer vir toegangsbesluite nie.
  static List<String> rights = <String>[];

  /// Kontroleer of die huidige sessie 'n gegewe reg het.
  static bool can(String right) => rights.contains(right);

  /// Helper-metode om rou data vanaf die API te verwerk.
  /// Dit sentraliseer die logika vir roldoewysing.
  /// Gooi 'n [StateError] as die API payload 'n geldige role_id ontbreeks.
  static void initialize(Map<String, dynamic> data) {
    userId = data['user_id'] ?? 0;
    userName =
        "${data['user_name'] ?? ''} ${data['user_surname'] ?? ''}".trim();
    userEmail = data['user_email'] ?? "";
    userCampus = data['location_name'] ?? "";
    locationId = data['location_id'];

    // Regte vanaf die backend — bepaal watter menu-items en aksies sigbaar is.
    final dynamic rawRights = data['rights'];
    rights = (rawRights is List)
        ? rawRights.map((e) => e.toString()).toList()
        : <String>[];

    // Roldoewysing gebaseer op ID vanaf die backend.
    // 3 = Admin, 2 = Manager (FK), 1 = Student, 4 = Contractor.
    final dynamic rawRoleId = data['role_id'];
    if (rawRoleId == null) {
      throw StateError(
        'Server response is missing role_id. '
        'Authentication may be invalid. Please re-login.',
      );
    }
    final int roleId = rawRoleId as int;
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
      case 1:
        role = UserRole.student;
        break;
      default:
        // Custom roles (id >= 5) can now be created via the admin UI. Access is
        // driven entirely by [rights], not this enum (which is only used for the
        // display roleTitle), so an unknown role_id must NOT crash login — fall
        // back to a neutral display role and rely on the rights list.
        role = UserRole.student;
        break;
    }
  }

  // Gerieflike getters vir vinnige toegangsbeheer in die UI.
  static bool get isAdmin => role == UserRole.admin;
  static bool get isManager => role == UserRole.manager;
  static bool get isContractor => role == UserRole.contractor;

  /// Bepaal of die gebruiker administratiewe aksies mag uitvoer.
  static bool get hasAdminPrivileges =>
      role == UserRole.admin || role == UserRole.manager;

  /// Maak die sessie skoon tydens logout.
  static void clear() {
    userId = 0;
    role = UserRole.student;
    userName = "";
    userEmail = "";
    userCampus = "";
    locationId = null;
    rights = <String>[];
  }
}
}
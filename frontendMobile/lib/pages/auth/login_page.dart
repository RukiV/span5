import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../../core/app_colors.dart';
import '../../models/user_session.dart';
import '../../core/api_client.dart';
import '../../services/outlook_token_manager.dart';
import '../settings/server_config_page.dart';

/// LoginPage: Die hoof-toegangspunt vir gebruikersstawing.
/// Dit ondersteun e-pos/wagwoord-aanmelding, Microsoft Outlook SSO,
/// en Biometriese verifikasie (vingerafdruk/gesig).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final LocalAuthentication auth = LocalAuthentication();
  final _secureStorage = const FlutterSecureStorage();

  bool _isLoading = false;
  bool _canCheckBiometrics = false;
  bool _obscurePassword = true; // Beheer die sigbaarheid van die wagwoord

  final TextEditingController _userControl = TextEditingController();
  final TextEditingController _passControl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  /// Inisieer biometriese vermoëns en kyk of die gebruiker dit voorheen geaktiveer het.
  Future<void> _initAuth() async {
    try {
      bool canCheck = await auth.canCheckBiometrics;
      bool isSupported = await auth.isDeviceSupported();
      setState(() => _canCheckBiometrics = canCheck || isSupported);

      if (_canCheckBiometrics) {
        final bioPref = await _secureStorage.read(key: 'use_biometrics');
        if (bioPref == 'true') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _authenticateWithBiometrics();
          });
        }
      }
    } catch (e) {
      debugPrint("Biometriese inisialisasie fout: $e");
    }
  }

  /// Hanteer die werklike biometriese skandering.
  Future<void> _authenticateWithBiometrics() async {
    try {
      bool authenticated = await auth.authenticate(
        localizedReason: 'Gebruik biometrie om vinnig aan te meld',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (authenticated && mounted) {
        _navigateToHome(isBioAuth: true);
      }
    } catch (e) {
      debugPrint("Biometriese stawing fout: $e");
    }
  }

  /// Die hoof-navigasie en stawing logika vir e-pos/wagwoord.
  Future<void> _navigateToHome({bool isBioAuth = false}) async {
    setState(() => _isLoading = true);

    if (!isBioAuth) {
      String email = _userControl.text.trim();
      String password = _passControl.text;

      if (email.isEmpty || password.isEmpty) {
        _showError("Vul asseblief alle velde in.");
        setState(() => _isLoading = false);
        return;
      }

      try {
        final response = await ApiClient().client.post(
          '/auth/login',
          data: {
            'user_email': email,
            'user_password': password,
          },
        );

        if (response.statusCode == 200) {
          final token = response.data['access_token'];
          final refreshToken = response.data['refresh_token'];

          // SEKURE BERGING: Gebruik ApiClient om die token geënkripteerd te stoor.
          await ApiClient().saveToken(token, refreshToken: refreshToken);

          await _fetchProfileAndNavigate();
          return;
        }
      } on DioException catch (e) {
        String msg = "Aanmelding het misluk.";

        debugPrint(
            "❌ Login error: status=${e.response?.statusCode} body=${e.response?.data}");

        // Verbeterde foutbestuur vir netwerk en spesifieke statuskodes.
        if (e.type == DioExceptionType.connectionError) {
          msg =
              "Kon nie die bediener bereik nie. Kontroleer jou internetverbinding of IP-adres.";
        } else if (e.response?.statusCode == 401) {
          final detail =
              e.response?.data is Map ? e.response?.data['detail'] : null;
          msg = detail ?? "Ongeldige e-pos of wagwoord.";
          debugPrint("   Login 401 detail: $detail");
        } else if (e.response?.statusCode == 403) {
          // Hanteer die platform-hekwagter boodskap vanaf die backend.
          msg = e.response?.data['detail'] ??
              "Jy het nie toegang tot hierdie stelsel nie.";
        }

        _showError(msg);
        setState(() => _isLoading = false);
        return;
      } catch (e) {
        _showError("Onverwagse fout: $e");
        setState(() => _isLoading = false);
        return;
      }
    } else {
      // Vir biometriese aanmelding word die token reeds deur die interseptor in ApiClient hanteer.
      await _fetchProfileAndNavigate();
    }
  }

  /// Laai die gebruiker se profiel en stel die UserSession sentraal op.
  Future<void> _fetchProfileAndNavigate() async {
    try {
      final response = await ApiClient().client.get('/auth/me');
      if (response.statusCode == 200) {
        // SENTRALE LOGIKA: Gebruik die UserSession klas om die data te inisieer.
        // Dit hanteer ook die roldoewysing (Admin/Manager/Student).
        UserSession.initialize(response.data);

        if (!mounted) return;

        if (_canCheckBiometrics) {
          final existing = await _secureStorage.read(key: 'use_biometrics');
          if (existing == null) {
            bool? wantBio = await _showBiometricPrompt();
            await _secureStorage.write(
                key: 'use_biometrics', value: (wantBio ?? false).toString());
          }
        }

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } on DioException catch (e) {
      debugPrint("Profiel laai fout: ${e.message}");
      _showError("Kon nie profiel laai nie. Teken asseblief weer in.");
      setState(() => _isLoading = false);
    } catch (e) {
      _showError("Fout met die verwerking van profiel-data.");
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Dialoog om biometrie te aktiveer na die eerste suksesvolle login.
  Future<bool?> _showBiometricPrompt() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Vinnige Intrekening",
            style:
                TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
        content: const Text(
            "Wil jy volgende keer biometrie (vingerafdruk of gesig) gebruik om vinniger in te teken?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("NEE DANKIE",
                  style: TextStyle(color: Colors.grey))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("JA, AKTIVEER")),
        ],
      ),
    );
  }

  /// Hanteer Microsoft Outlook SSO aanmelding.
  /// Dieselfde vloei as die web (frontend/): meld aan via die Azure-app met
  /// `User.Read + Calendars.ReadWrite`, hou die Graph-token vir kalendersinkronisering
  /// en verruil dit vir die app se eie sessietoken by die backend.
  Future<void> _outlookLogin() async {
    // flutter_appauth (stelsel-webblaaier) ondersteun nie Windows/Linux nie —
    // wys net 'n boodskap.
    if (!Platform.isAndroid && !Platform.isIOS) {
      _showError("Microsoft-sign-in is nie beskikbaar op hierdie toestel nie.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final signedIn = await OutlookTokenManager.instance.signIn();
      if (!signedIn || !mounted) {
        setState(() => _isLoading = false);
        return;
      }

      final accessToken =
          await OutlookTokenManager.instance.getGraphAccessToken();
      if (accessToken == null) {
        setState(() => _isLoading = false);
        _showError("Kon nie die Microsoft-token verkry nie.");
        return;
      }

      final response = await ApiClient().client.post(
        '/auth/microsoft',
        data: {'microsoft_token': accessToken},
      );

      if (response.statusCode == 200) {
        final token = response.data['access_token'];
        final refreshToken = response.data['refresh_token'];
        await ApiClient().saveToken(token, refreshToken: refreshToken);
        await _fetchProfileAndNavigate();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("Outlook SSO Fout: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Vertoon laai-skerm indien besig.
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.navy,
        body: _buildBackground(
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.gold),
                const SizedBox(height: 25),
                const Text("Besig om aan te meld...",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1)),
                const SizedBox(height: 8),
                Text("Een oomblik asseblief",
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: _buildBackground(
        Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                children: [
                  // Hoof aanmeldingshouer
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 25, vertical: 40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5))
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/images/logo.png', width: 333),
                        const SizedBox(height: 10),
                        const Text("FBS - Fasiliteitsbestuurstelsel",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: Colors.black)),
                        const SizedBox(height: 6),
                        const SizedBox(height: 35),

                        _buildInputLabel("E-pos Adres"),
                        TextField(
                          controller: _userControl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDecoration("e-pos adres"),
                        ),
                        const SizedBox(height: 20),

                        _buildInputLabel("Wagwoord"),
                        TextField(
                          controller: _passControl,
                          obscureText: _obscurePassword,
                          decoration: _inputDecoration("wagwoord").copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),

                        // Aanmeld-knoppie
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: AppColors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _navigateToHome(),
                            child: const Text("Teken In",
                                style: TextStyle(
                                    fontSize: 16, letterSpacing: 1.2)),
                          ),
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Text("of",
                                      style: TextStyle(color: Colors.grey))),
                              Expanded(child: Divider()),
                            ],
                          ),
                        ),

                        // Microsoft SSO Alternatief
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: AppColors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _outlookLogin,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _microsoftIcon(),
                                const SizedBox(width: 10),
                                const Text("Teken in met Microsoft",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        letterSpacing: 1.2)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ServerConfigPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.dns,
                              size: 16, color: Colors.grey),
                          label: const Text(
                            "Bediener-instellings",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackground(Widget child) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.jpg'),
                fit: BoxFit.cover,
                alignment: Alignment.topRight,
              ),
          ),
        ),
        child,
      ],
    );
  }

  /// Styl vir die inset-velde (soos web).
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black26),
      fillColor: AppColors.white,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: AppColors.gold),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    );
  }

  Widget _buildInputLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 5, left: 2),
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }

  /// Visuele voorstelling van die Microsoft logo.
  Widget _microsoftIcon() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          _colorBox(Colors.red),
          const SizedBox(width: 2),
          _colorBox(Colors.green)
        ]),
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _colorBox(Colors.blue),
          const SizedBox(width: 2),
          _colorBox(Colors.yellow)
        ]),
      ],
    );
  }

  Widget _colorBox(Color c) => Container(width: 7, height: 7, color: c);
}

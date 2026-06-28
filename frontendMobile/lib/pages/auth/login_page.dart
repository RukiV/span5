import 'package:flutter/material.dart';
import 'package:aad_oauth/aad_oauth.dart';
import 'package:aad_oauth/model/config.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../main.dart';
import '../../core/app_colors.dart';
import '../../models/user_session.dart';
import '../../core/api_client.dart';
import '../../core/auth_config.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isLoading = false;
  bool _canCheckBiometrics = false;
  late AadOAuth oauth;
  
  final TextEditingController _userControl = TextEditingController();
  final TextEditingController _passControl = TextEditingController();

  final Config config = Config(
    tenant: AuthConfig.tenantId,
    clientId: AuthConfig.clientId,
    scope: AuthConfig.scopes.join(' '),
    redirectUri: AuthConfig.redirectUri,
    navigatorKey: navigatorKey,
  );

  @override
  void initState() {
    super.initState();
    oauth = AadOAuth(config);
    _initAuth();
  }

  Future<void> _initAuth() async {
    try {
      // Kyk of die toestel biometrie ondersteun
      bool canCheck = await auth.canCheckBiometrics;
      bool isSupported = await auth.isDeviceSupported();
      setState(() => _canCheckBiometrics = canCheck || isSupported);
      
      if (_canCheckBiometrics) {
        final prefs = await SharedPreferences.getInstance();
        bool useBio = prefs.getBool('use_biometrics') ?? false;
        
        if (useBio) {
          // Wag vir die UI om te stabiliseer voor die prompt verskyn
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _authenticateWithBiometrics();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      bool authenticated = await auth.authenticate(
        localizedReason: 'Gebruik biometrie om vinnig aan te meld by Akademia',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (authenticated && mounted) {
        _navigateToHome(isBioAuth: true);
      }
    } catch (_) {}
  }

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
        // Gebruik 'n timeout vir beter sekuriteit en UX
        final response = await ApiClient.dio.post(
          '/auth/login',
          data: {
            'user_email': email,
            'user_password': password,
          },
          options: Options(
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );

        if (response.statusCode == 200) {
          final token = response.data['access_token'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          
          await _fetchProfileAndNavigate();
          return;
        }
      } on DioException catch (e) {
        String msg = "Aanmelding het misluk.";
        if (e.response?.statusCode == 401) {
          msg = "Ongeldige e-pos of wagwoord.";
        } else if (e.response?.statusCode == 403) {
          msg = e.response?.data['detail'] ?? "Jy het nie toegang tot hierdie stelsel nie.";
        }
        _showError(msg);
        setState(() => _isLoading = false);
        return;
      } catch (e) {
        _showError("Fout: $e");
        setState(() => _isLoading = false);
        return;
      }
    } else {
      // Biometriese login - ons neem aan die token is reeds daar
      await _fetchProfileAndNavigate();
    }
  }

  Future<void> _fetchProfileAndNavigate() async {
    try {
      final response = await ApiClient.dio.get('/auth/me');
      if (response.statusCode == 200) {
        final data = response.data;
        UserSession.userId = data['user_id'];
        UserSession.userName = "${data['user_name']} ${data['user_surname']}";
        UserSession.userEmail = data['user_email'];
        
        // Map role_id na UserRole
        int roleId = data['role_id'];
        if (roleId == 3) {
          UserSession.role = UserRole.admin;
        } else if (roleId == 2) {
          UserSession.role = UserRole.manager;
        } else {
          UserSession.role = UserRole.student;
        }

        if (!mounted) return;
        
        // Biometrie check as dit die eerste keer is
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('use_biometrics') == null && _canCheckBiometrics) {
          bool? wantBio = await _showBiometricPrompt();
          await prefs.setBool('use_biometrics', wantBio ?? false);
        }

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      _showError("Kon nie profiel laai nie.");
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<bool?> _showBiometricPrompt() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Vinnige Intrekening", style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
        content: const Text("Wil jy volgende keer biometrie (vingerafdruk of gesig) gebruik om vinniger in te teken?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("NEE DANKIE", style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("JA, AKTIVEER")),
        ],
      ),
    );
  }

  Future<void> _outlookLogin() async {
    setState(() => _isLoading = true);
    try {
      await oauth.login();
      String? accessToken = await oauth.getAccessToken();
      if (accessToken != null && mounted) {
        // Stuur Microsoft token na backend
        final response = await ApiClient.dio.post(
          '/auth/microsoft',
          data: {'microsoft_token': accessToken},
        );

        if (response.statusCode == 200) {
          final token = response.data['access_token'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          
          await _fetchProfileAndNavigate();
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("Outlook Fout: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.navy,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.gold),
              const SizedBox(height: 25),
              const Text("Besig om aan te meld...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
              const SizedBox(height: 8),
              Text("Een oomblik asseblief", style: TextStyle(color: Colors.white.withValues(alpha: 150/255), fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(25.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 76/255), blurRadius: 15, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Teken In", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.navy)),
                      const SizedBox(height: 35),
                      _buildInputLabel("E-pos Adres"),
                      TextField(
                        controller: _userControl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: "admin@akademia.co.za",
                          fillColor: AppColors.inputFill,
                          filled: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildInputLabel("Wagwoord"),
                      TextField(
                        controller: _passControl,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: "••••••••",
                          fillColor: AppColors.inputFill,
                          filled: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(onPressed: () => _navigateToHome(), child: const Text("LOGIN", style: TextStyle(fontSize: 16, letterSpacing: 1.2))),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("of", style: TextStyle(color: Colors.grey))),
                            Expanded(child: Divider()),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          side: const BorderSide(color: Colors.grey, width: 0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _outlookLogin,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _microsoftIcon(),
                            const SizedBox(width: 10),
                            const Text("Teken in met Microsoft", style: TextStyle(color: Colors.black87)),
                          ],
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
    );
  }

  Widget _buildInputLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 5, left: 2),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }

  Widget _microsoftIcon() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [_colorBox(Colors.red), const SizedBox(width: 2), _colorBox(Colors.green)]),
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, children: [_colorBox(Colors.blue), const SizedBox(width: 2), _colorBox(Colors.yellow)]),
      ],
    );
  }
  Widget _colorBox(Color c) => Container(width: 7, height: 7, color: c);
}

import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';

/// ServerConfigPage: Eerste-launch / instellingsskerm waar die gebruiker die
/// bediener-URL invoer (bv. https://jou-tunnel.trycloudflare.com of 'n LAN-IP).
/// Die URL word in sekuriteitsberging gestoor sodat 'n enkele APK met enige
/// bediener kan verbind — geen herverpakking nodig wanneer die URL verander nie.
class ServerConfigPage extends StatefulWidget {
  /// true wanneer hierdie skerm tydens die eerste-launch gewys word (dan
  /// navigeer dit na die aanmeldskerm na stoor). false vir instellings-toegang.
  final bool firstLaunch;

  const ServerConfigPage({super.key, this.firstLaunch = false});

  @override
  State<ServerConfigPage> createState() => _ServerConfigPageState();
}

class _ServerConfigPageState extends State<ServerConfigPage> {
  final TextEditingController _urlControl = TextEditingController();
  bool _saving = false;
  bool _hasServer = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUrl();
  }

  Future<void> _loadCurrentUrl() async {
    final stored = await ApiClient.getStoredServerUrl();
    _hasServer = stored != null && stored.isNotEmpty;
    if (mounted) {
      _urlControl.text =
          stored ?? (ApiClient().baseUrl.startsWith('http') ? ApiClient().baseUrl : '');
    }
  }

  String? _validate(String value) {
    final url = value.trim();
    if (url.isEmpty) return "Voer die bediener-URL in.";
    if (!url.startsWith('https://') && !url.startsWith('http://')) {
      return "Die URL moet met https:// of http:// begin.";
    }
    return null;
  }

  Future<void> _save() async {
    final error = _validate(_urlControl.text);
    if (error != null) {
      _showError(error);
      return;
    }

    setState(() => _saving = true);
    try {
      await ApiClient().setBaseUrl(_urlControl.text);
      if (!mounted) return;

      if (widget.firstLaunch) {
        // Eerste keer: gaan na die aanmeldskerm.
        Navigator.pushReplacementNamed(context, '/');
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      _showError("Kon nie die bediener-URL stoor nie: $e");
      if (mounted) setState(() => _saving = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        title: const Text("Bediener-instellings"),
        backgroundColor: AppColors.navy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.dns, color: AppColors.gold, size: 44),
                const SizedBox(height: 12),
                const Text(
                  "Bediener-Adres",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _hasServer
                      ? "Wysig die bediener-URL hieronder. Maak seker jou toestel "
                          "kan by hierdie adres uitkom (internet of selfde WiFi)."
                      : "Voer die adres van jou FBS-bediener in. Dit is die URL wat "
                          "jy met die webwerf deel — byvoorbeeld:\n"
                          "https://jou-tunnel.trycloudflare.com",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _urlControl,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: "Bediener-URL",
                    hintText: "https://jou-bediener/api/v1",
                    hintStyle: const TextStyle(color: Colors.black26),
                    fillColor: AppColors.inputFill,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.black12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.black12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.black38),
                    ),
                    prefixIcon: const Icon(Icons.link, color: AppColors.navy),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text("Stoor en Gaan Voort",
                            style: TextStyle(fontSize: 16, letterSpacing: 1.1)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
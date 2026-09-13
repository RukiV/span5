import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/app_colors.dart';

class ScanPage extends StatefulWidget {
  final bool isLocation;
  const ScanPage({super.key, this.isLocation = false});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController cameraController = MobileScannerController(
    formats: [BarcodeFormat.all],
    detectionSpeed: DetectionSpeed.normal,
  );
  bool _isDetected = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    cameraController.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // 1. DIE LIVE KAMERA
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                MobileScanner(
                  controller: cameraController,
                  onDetect: (capture) {
                    if (_isDetected) return;
                    final String? code = capture.barcodes.firstOrNull?.rawValue;
                    if (code != null && code.isNotEmpty) {
                      _isDetected = true;
                      Navigator.pop(context, code);
                    }
                  },
                ),
                // --- NUWE LOADING SKERM ---
                ValueListenableBuilder<MobileScannerState>(
                  valueListenable: cameraController,
                  builder: (context, state, child) {
                    if (!state.isInitialized || state.isRunning == false) {
                      return Container(
                        color: Colors.black,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(color: AppColors.gold),
                              const SizedBox(height: 15),
                              Text(
                                "Kamera laai...",
                                style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                // Donker Oorlegsel
                ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.5),
                    BlendMode.srcOut,
                  ),
                  child: Stack(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          backgroundBlendMode: BlendMode.dstOut,
                        ),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          height: 250,
                          width: 250,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Goue Grense
                Center(
                  child: CustomPaint(
                    foregroundPainter: BorderPainter(),
                    child: const SizedBox(
                      width: 250,
                      height: 250,
                    ),
                  ),
                ),
                // Flits en Toe knoppies
                Positioned(
                  top: 50,
                  right: 20,
                  child: CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      color: Colors.white,
                      icon: ValueListenableBuilder<MobileScannerState>(
                        valueListenable: cameraController,
                        builder: (context, state, child) {
                          switch (state.torchState) {
                            case TorchState.on: return const Icon(Icons.flash_on, color: AppColors.lightGold);
                            default: return const Icon(Icons.flash_off, color: Colors.white);
                          }
                        },
                      ),
                      onPressed: () => cameraController.toggleTorch(),
                    ),
                  ),
                ),
                Positioned(
                  top: 50,
                  left: 20,
                  child: CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. DIE VOORBEELD / SCENARIO GEDEELTE
          Container(
            height: 220,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isLocation ? "LOKAAL SKANDERING" : "BATE IDENTIFIKASIE",
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Die Voorbeeld Prentjie Placeholder
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: widget.isLocation 
                          ? const Icon(Icons.door_sliding, color: Colors.white24, size: 40)
                          : const Icon(Icons.chair, color: Colors.white24, size: 40),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Die Beskrywing
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isLocation ? "Ligging-kode voorbeeld:" : "Bate-kode voorbeeld:",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.isLocation 
                              ? "Soek die QR-kode teen die muur by die ingang. Skandeer vanaf ongeveer 1 meter."
                              : "Soek die goue plakker op die meubels of IT voorraad. Rig die raam op die kode.",
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Center(
                  child: Text(
                    widget.isLocation ? "Skandeer die kode teen die muur" : "Skandeer die kode op die item",
                    style: const TextStyle(color: AppColors.gold, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double sh = size.height;
    double sw = size.width;
    double cornerSize = 30;
    Paint paint = Paint()
      ..color = AppColors.lightGold
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    Path path = Path();
    path.moveTo(0, cornerSize); path.lineTo(0, 0); path.lineTo(cornerSize, 0); // TL
    path.moveTo(sw - cornerSize, 0); path.lineTo(sw, 0); path.lineTo(sw, cornerSize); // TR
    path.moveTo(sw, sh - cornerSize); path.lineTo(sw, sh); path.lineTo(sw - cornerSize, sh); // BR
    path.moveTo(cornerSize, sh); path.lineTo(0, sh); path.lineTo(0, sh - cornerSize); // BL
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

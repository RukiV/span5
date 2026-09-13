import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Foutboodskap + "Probeer weer"-knoppie vir 'n mislukte lyslaai.
class ListLoadError extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;

  const ListLoadError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: AppColors.errorRed, size: 40),
            const SizedBox(height: 12),
            Text(
              message ?? "Kon nie die kampuslys laai nie.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.errorRed),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text("Probeer weer"),
            ),
          ],
        ),
      ),
    );
  }
}
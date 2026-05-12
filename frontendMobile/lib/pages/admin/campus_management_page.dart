import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/campus_service.dart';
import '../../models/campus.dart';
import 'add_campus_page.dart';

class CampusManagementPage extends StatelessWidget {
  const CampusManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Kampus Bestuur"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.gold),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddCampusPage()),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<List<Campus>>(
        valueListenable: CampusService.campusesNotifier,
        builder: (context, campuses, child) {
          if (campuses.isEmpty) {
            return const Center(
              child: Text("Geen kampusse gevind nie. Voeg een by met die + knoppie."),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: campuses.length,
            itemBuilder: (context, index) {
              final campus = campuses[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  title: Text(
                    campus.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text(campus.address, style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 5),
                      Text(
                        "Koördinate: ${campus.location.latitude.toStringAsFixed(6)}, ${campus.location.longitude.toStringAsFixed(6)}",
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () {
                      _showDeleteDialog(context, campus);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Campus campus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Verwyder Kampus?"),
        content: Text("Is jy seker jy wil ${campus.name} verwyder?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("KANSELLEER")),
          TextButton(
            onPressed: () {
              CampusService.removeCampus(campus.id);
              Navigator.pop(context);
            },
            child: const Text("VERWYDER", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/campus_service.dart';
import '../../models/campus.dart';
import 'add_campus_page.dart';

class CampusManagementPage extends StatefulWidget {
  const CampusManagementPage({super.key});

  @override
  State<CampusManagementPage> createState() => _CampusManagementPageState();
}

class _CampusManagementPageState extends State<CampusManagementPage> {
  @override
  void initState() {
    super.initState();
    CampusService.fetchCampuses();
  }

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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_city_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text("Geen kampusse gevind nie."),
                  TextButton(
                    onPressed: () => CampusService.fetchCampuses(),
                    child: const Text("HERLAAI"),
                  )
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => CampusService.fetchCampuses(),
            child: ListView.builder(
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
                          "${campus.rooms.length} Lokale geregistreer",
                          style: const TextStyle(fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // Toekomstige funksie: Sien spesifieke lokale
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

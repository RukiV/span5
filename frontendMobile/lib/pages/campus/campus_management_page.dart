import '../../models/user_session.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/campus_service.dart';
import '../../models/campus.dart';
import 'add_campus_page.dart';
import 'campus_detail_page.dart';

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
      body: ValueListenableBuilder<List<Campus>>(
        valueListenable: CampusService.campusesNotifier,
        builder: (context, allCampuses, child) {
          // ROL-GEBASEERDE DATA FILTRERING
          List<Campus> campuses = allCampuses;
          if (UserSession.isManager) {
            campuses = allCampuses.where((c) => c.name == UserSession.userCampus).toList();
          }

          if (campuses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (UserSession.isAdmin)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AddCampusPage()),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text("Voeg Terrein By"),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.white),
                      ),
                    ),
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
            child: Column(
              children: [
                if (UserSession.isAdmin)
                  Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AddCampusPage()),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text("VOEG NUWE TERREIN BY"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
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
                                "${campus.buildings.length} Geboue",
                                style: const TextStyle(fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right, color: AppColors.gold),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CampusDetailPage(campus: campus),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

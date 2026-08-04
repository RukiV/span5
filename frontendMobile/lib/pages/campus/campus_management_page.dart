import '../../models/user_session.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/campus_service.dart';
import '../../models/campus.dart';
import 'add_campus_page.dart';
import 'campus_detail_page.dart';
import '../../widgets/sort_utils.dart';
import '../../widgets/column_visibility.dart';

class CampusManagementPage extends StatefulWidget {
  const CampusManagementPage({super.key});

  @override
  State<CampusManagementPage> createState() => _CampusManagementPageState();
}

class _CampusManagementPageState extends State<CampusManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  final SortController _sortCtrl = SortController();
  final ColumnVisibilityController _colVis = ColumnVisibilityController('campuses', [
    const ColumnDef(key: 'name', label: 'Naam'),
    const ColumnDef(key: 'address', label: 'Adres', defaultVisible: false),
    const ColumnDef(key: 'buildings', label: 'Geboue'),
  ]);
  String _query = "";

  @override
  void initState() {
    super.initState();
    CampusService.fetchCampuses();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ValueListenableBuilder<List<Campus>>(
        valueListenable: CampusService.campusesNotifier,
        builder: (context, allCampuses, child) {
          List<Campus> campuses = allCampuses;

          if (campuses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (UserSession.hasAdminPrivileges)
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

          final filtered = campuses.where((c) =>
              c.name.toLowerCase().contains(_query) ||
              c.address.toLowerCase().contains(_query)
          ).toList();

          if (_sortCtrl.isActive) {
            filtered.sort((a, b) {
              final dir = _sortCtrl.direction;
              switch (_sortCtrl.sortKey) {
                case 'name':
                  return a.name.toLowerCase().compareTo(b.name.toLowerCase()) * dir;
                case 'address':
                  return a.address.toLowerCase().compareTo(b.address.toLowerCase()) * dir;
                case 'buildings':
                  return a.buildings.length.compareTo(b.buildings.length) * dir;
                default:
                  return 0;
              }
            });
          }

          return RefreshIndicator(
            onRefresh: () => CampusService.fetchCampuses(),
            child: Column(
              children: [
                Container(
                  color: AppColors.navy,
                  padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Soek terreine...",
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 150 / 255), fontSize: 14),
                            prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                            fillColor: Colors.white.withValues(alpha: 30 / 255),
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ColumnVisibilityButton(controller: _colVis),
                    ],
                  ),
                ),
                if (UserSession.hasAdminPrivileges)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
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
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final campus = filtered[index];
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

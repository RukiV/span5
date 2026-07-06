import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/contractor_service.dart';
import '../../models/contractor.dart';
import '../../models/user_session.dart';
import 'add_contractor_page.dart';
import 'edit_contractor_page.dart';

class ContractorManagementPage extends StatefulWidget {
  const ContractorManagementPage({super.key});

  @override
  State<ContractorManagementPage> createState() => _ContractorManagementPageState();
}

class _ContractorManagementPageState extends State<ContractorManagementPage> {
  @override
  void initState() {
    super.initState();
    ContractorService.fetchContractors();
  }

  Future<void> _deleteContractor(Contractor contractor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Verwyder Kontrakteur"),
        content: Text("Is jy seker jy wil '${contractor.fullName}' verwyder?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("KANSELLEER")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("VERWYDER", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ContractorService.deleteContractor(contractor.id);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Kontrakteur suksesvol verwyder"), backgroundColor: AppColors.successGreen),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Fout met verwydering"), backgroundColor: AppColors.errorRed),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          if (UserSession.hasAdminPrivileges)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddContractorPage()),
                    );
                    if (result == true) setState(() {});
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("VOEG NUWE KONTRAKTEUR BY"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          Expanded(
            child: ValueListenableBuilder<List<Contractor>>(
              valueListenable: ContractorService.contractorsNotifier,
              builder: (context, contractors, _) {
                if (contractors.isEmpty) {
                  return const Center(child: Text("Geen kontrakteurs gevind nie.", style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: contractors.length,
                  itemBuilder: (context, index) {
                    final c = contractors[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(15),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                          child: Text(c.name[0], style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(
                          c.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.email, style: const TextStyle(fontSize: 13)),
                            if (c.phone != null && c.phone!.isNotEmpty)
                              Text(c.phone!, style: const TextStyle(fontSize: 13)),
                            if (c.type != null && c.type!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  c.type!,
                                  style: const TextStyle(fontSize: 11, color: AppColors.gold, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        trailing: UserSession.hasAdminPrivileges
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => EditContractorPage(contractor: c)),
                                      );
                                      if (result == true) setState(() {});
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                    onPressed: () => _deleteContractor(c),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

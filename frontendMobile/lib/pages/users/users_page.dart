import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/user.dart';
import '../../models/user_session.dart';
import '../../services/user_service.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/fixed_page_header.dart';
import '../../widgets/header_action_button.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = "";

  @override
  void initState() {
    super.initState();
    UserService.fetchUsers();
    if (UserService.rolesNotifier.value.isEmpty) {
      UserService.fetchRoles();
    }
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<User> get _filteredUsers {
    final users = UserService.usersNotifier.value;
    if (_query.isEmpty) return users;
    return users
        .where((u) =>
            u.fullName.toLowerCase().contains(_query) ||
            u.email.toLowerCase().contains(_query))
        .toList();
  }

  Future<void> _showUserDialog({User? existing}) async {
    final isEdit = existing != null;

    // Die rol-kieslys is nodig vir beide nuwe en gewysigde gebruikers; sonder
    // dit kan 'n stoor stilweg na rol 1 (Student) terugval.
    if (UserService.rolesNotifier.value.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Rolle kon nie gelaai word nie. Verfris en probeer weer."),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
      return;
    }

    final nameController = TextEditingController(text: existing?.name ?? "");
    final surnameController = TextEditingController(text: existing?.surname ?? "");
    final emailController = TextEditingController(text: existing?.email ?? "");
    final numberController = TextEditingController(text: existing?.number ?? "");
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    int? roleId = existing?.roleId;
    String status = existing?.status ?? "active";

    await showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isEdit ? "Wysig Gebruiker" : "Nuwe Gebruiker",
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(dialogContext)),
                  ],
                ),
                const SizedBox(height: 20),
                _field("Naam", nameController),
                const SizedBox(height: 16),
                _field("Van", surnameController),
                const SizedBox(height: 16),
                _field("E-pos", emailController,
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                _field("Telefoonnommer", numberController,
                    keyboardType: TextInputType.phone),
                if (!isEdit) ...[
                  const SizedBox(height: 16),
                  _field("Wagwoord", passwordController,
                      obscureText: true, required: true),
                ],
                const SizedBox(height: 16),
                ValueListenableBuilder<List<AppRole>>(
                  valueListenable: UserService.rolesNotifier,
                  builder: (context, roles, _) => SearchableDropdown<int>(
                    label: "Rol",
                    hint: "Kies 'n rol",
                    value: roleId,
                    items: roles
                        .map((r) => SearchableDropdownItem(value: r.id, label: r.name))
                        .toList(),
                    onChanged: (v) => roleId = v,
                    validator: (v) => (v == null) ? "Vereis" : null,
                  ),
                ),
                const SizedBox(height: 16),
                SearchableDropdown<String>(
                  label: "Status",
                  hint: "Kies status",
                  value: status,
                  items: const [
                    SearchableDropdownItem(value: "active", label: "Aktief"),
                    SearchableDropdownItem(value: "inactive", label: "Onaktief"),
                  ],
                  onChanged: (v) => status = v ?? "active",
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text("Kanselleer",
                          style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        if (nameController.text.trim().isEmpty ||
                            surnameController.text.trim().isEmpty ||
                            emailController.text.trim().isEmpty ||
                            (isEdit ? false : passwordController.text.isEmpty)) {
                          return;
                        }
                        if (roleId == null) {
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Kies 'n rol vir die gebruiker"),
                                backgroundColor: AppColors.errorRed,
                              ),
                            );
                          }
                          return;
                        }
                        final user = User(
                          id: existing?.id,
                          name: nameController.text.trim(),
                          surname: surnameController.text.trim(),
                          email: emailController.text.trim(),
                          number: numberController.text.trim().isEmpty
                              ? null
                              : numberController.text.trim(),
                          status: status,
                          roleId: roleId!,
                        );
                        final ok = isEdit
                            ? await UserService.updateUser(user,
                                password: passwordController.text)
                            : await UserService.addUser(
                                user, passwordController.text);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? (isEdit
                                      ? "Gebruiker opgedateer"
                                      : "Gebruiker geskep")
                                  : "Kon nie stoor nie"),
                              backgroundColor:
                                  ok ? AppColors.successGreen : AppColors.errorRed,
                            ),
                          );
                        }
                      },
                      child: const Text("Stoor",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      {bool obscureText = false,
      bool required = false,
      TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          autofillHints: obscureText ? const [] : null,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14),
          validator: required
              ? (v) => (v == null || v.isEmpty) ? "Vereis" : null
              : null,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.gold, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          ),
        ),
      ],
    );
  }

  void _reload() {
    UserService.fetchUsers();
    UserService.fetchRoles();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FixedPageHeader(
          controller: _searchController,
          hintText: "Soek gebruikers...",
          onChanged: (_) => setState(() {}),
          actions: [
            HeaderIconAction(
              icon: Icons.refresh,
              tooltip: "Verfris",
              onTap: _reload,
            ),
          ],
        ),
        if (UserSession.can('users.manage'))
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showUserDialog(),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text("VOEG NUWE GEBRUIKER BY"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        Expanded(
          child: ListenableBuilder(
            listenable: Listenable.merge([
              UserService.usersNotifier,
              UserService.usersLoadingNotifier,
              UserService.usersLoadFailedNotifier,
            ]),
            builder: (context, _) {
              final users = UserService.usersNotifier.value;
              if (UserService.usersLoadingNotifier.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (UserService.usersLoadFailedNotifier.value) {
                return _errorState();
              }
              final filtered = _filteredUsers;
              if (filtered.isEmpty) {
                return Center(
                  child: Text(users.isEmpty
                      ? "Geen gebruikers nie"
                      : "Geen gebruikers gevind nie"),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: filtered.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = filtered[index];
                  return _userTile(user);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _errorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          const Text("Kon nie gebruikers laai nie"),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
            onPressed: _reload,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text("Probeer weer",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _userTile(User user) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.lavender,
        child: Text(
          user.name.isNotEmpty ? user.name[0].toUpperCase() : "?",
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
        ),
      ),
      title: Text(
        user.fullName,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      subtitle: Text(
        "${user.email}\n${UserService.roleName(user.roleId)}",
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: user.isActive
                  ? AppColors.successGreen.withValues(alpha: 0.15)
                  : AppColors.errorRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              user.isActive ? "Aktief" : "Onaktief",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: user.isActive
                    ? AppColors.successGreen
                    : AppColors.errorRed,
              ),
            ),
          ),
          if (UserSession.can('users.manage')) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              color: AppColors.navy,
              onPressed: () => _showUserDialog(existing: user),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AppColors.errorRed,
              onPressed: () => _confirmDelete(user),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text("Gebruiker verwyder"),
        content: Text("Seeker om ${user.fullName} te verwyder?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Kanselleer", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Verwyder", style: TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || user.id == null) return;
    final ok = await UserService.deleteUser(user.id!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? "Gebruiker verwyder" : "Kon nie verwyder nie"),
          backgroundColor: ok ? AppColors.successGreen : AppColors.errorRed,
        ),
      );
    }
  }
}

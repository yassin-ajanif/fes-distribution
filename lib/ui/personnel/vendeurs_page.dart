import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/common/confirm_dialog.dart';
import 'package:fes_distribution/ui/common/loading_view.dart';
import 'package:fes_distribution/ui/common/shell_app_bar.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

class VendeursPage extends ConsumerStatefulWidget {
  const VendeursPage({super.key});

  @override
  ConsumerState<VendeursPage> createState() => _VendeursPageState();
}

class _VendeursPageState extends ConsumerState<VendeursPage> {
  final _searchController = TextEditingController();
  List<User> _vendeurs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await ref.read(userServiceProvider).listVendeurs(
            search: _searchController.text,
          );
      if (!mounted) return;
      setState(() {
        _vendeurs = rows;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        await showErrorDialog(context, title: context.s.menuVendeurs, message: '$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: ShellAppBar(
        title: s.menuVendeurs,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/distribution/vendeurs/new'),
        icon: const Icon(Icons.person_add),
        label: Text(s.actionNew),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: s.searchVendeur,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _load();
                  },
                ),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          Expanded(
            child: _loading
                ? LoadingView(message: s.loading)
                : _vendeurs.isEmpty
                    ? Center(
                        child: Text(
                          s.emptyVendeurs,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88), // FAB clearance
                          itemCount: _vendeurs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final v = _vendeurs[index];
                            return Card(
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: AppColors.brandSoft,
                                  child: Icon(Icons.person, color: AppColors.brand),
                                ),
                                title: Text(v.fullName),
                                subtitle: Text(v.phone),
                                trailing: v.actif
                                    ? const Icon(Icons.chevron_right)
                                    : const Icon(Icons.block, color: AppColors.muted),
                                onTap: () =>
                                    context.push('/distribution/vendeurs/${v.id}'),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

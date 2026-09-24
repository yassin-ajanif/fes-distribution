import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/business/models/bon_decharge_list_item.dart';
import 'package:fes_distribution/ui/common/confirm_dialog.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/loading_view.dart';
import 'package:fes_distribution/ui/common/responsive.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

class BonDechargeListPage extends ConsumerStatefulWidget {
  const BonDechargeListPage({super.key});

  @override
  ConsumerState<BonDechargeListPage> createState() =>
      _BonDechargeListPageState();
}

class _BonDechargeListPageState extends ConsumerState<BonDechargeListPage> {
  final _searchController = TextEditingController();
  List<BonDechargeListItem> _items = [];
  bool _loading = true;
  BonDechargeListItem? _selected;

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
      final items = await ref.read(bonDechargeServiceProvider).list(
            search: _searchController.text,
          );
      if (!mounted) return;
      setState(() {
        _items = items;
        if (_selected != null) {
          _selected = items.cast<BonDechargeListItem?>().firstWhere(
                (i) => i?.bon.id == _selected!.bon.id,
                orElse: () => null,
              );
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        await showErrorDialog(context, title: 'Bon décharge', message: '$e');
      }
    }
  }

  Future<void> _deleteItem(BonDechargeListItem item) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Bon décharge',
      message: 'Supprimer ${item.bon.numero} ?',
    );
    if (!ok) return;

    setState(() => _loading = true);
    try {
      await ref.read(bonDechargeWorkflowProvider).delete(item.bon.id);
      _selected = null;
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        await showErrorDialog(context, title: 'Bon décharge', message: '$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bons de décharge'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/distribution/bons-decharge/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher numéro, vendeur, note…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _load,
                ),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _items.isEmpty
                    ? Center(
                        child: Text(
                          'Aucun bon de décharge.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : mobile
                        ? _MobileList(
                            items: _items,
                            onTap: (item) => context.push(
                              '/distribution/bons-decharge/${item.bon.id}',
                            ),
                            onDelete: _deleteItem,
                          )
                        : _DesktopTable(
                            items: _items,
                            selected: _selected,
                            onSelect: (item) => setState(() => _selected = item),
                            onOpen: (item) => context.push(
                              '/distribution/bons-decharge/${item.bon.id}',
                            ),
                            onDelete: _deleteItem,
                          ),
          ),
        ],
      ),
    );
  }
}

class _MobileList extends StatelessWidget {
  const _MobileList({
    required this.items,
    required this.onTap,
    required this.onDelete,
  });

  final List<BonDechargeListItem> items;
  final ValueChanged<BonDechargeListItem> onTap;
  final Future<void> Function(BonDechargeListItem) onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return Dismissible(
          key: ValueKey(item.bon.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            await onDelete(item);
            return true;
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: AppColors.danger,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(
                item.bon.numero,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.assignedToNom),
                  Text(dateFormat.format(item.bon.date)),
                  if (item.bon.note.isNotEmpty) Text(item.bon.note),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onTap(item),
            ),
          ),
        );
      },
    );
  }
}

class _DesktopTable extends StatelessWidget {
  const _DesktopTable({
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
    required this.onDelete,
  });

  final List<BonDechargeListItem> items;
  final BonDechargeListItem? selected;
  final ValueChanged<BonDechargeListItem> onSelect;
  final ValueChanged<BonDechargeListItem> onOpen;
  final Future<void> Function(BonDechargeListItem) onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (selected != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilledButton(
                  onPressed: () => onOpen(selected!),
                  child: const Text('Ouvrir'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => onDelete(selected!),
                  child: const Text('Supprimer'),
                ),
              ],
            ),
          ),
        Expanded(
          child: Card(
            margin: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.brandSoft),
                columns: const [
                  DataColumn(label: Text('Numéro')),
                  DataColumn(label: Text('Vendeur')),
                  DataColumn(label: Text('Dépôt')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Note')),
                ],
                rows: items
                    .map(
                      (item) => DataRow(
                        selected: selected?.bon.id == item.bon.id,
                        onSelectChanged: (_) => onSelect(item),
                        cells: [
                          DataCell(Text(item.bon.numero)),
                          DataCell(Text(item.assignedToNom)),
                          DataCell(Text(item.depotNom)),
                          DataCell(Text(dateFormat.format(item.bon.date))),
                          DataCell(Text(item.bon.note)),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

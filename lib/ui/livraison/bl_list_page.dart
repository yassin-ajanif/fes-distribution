import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/business/models/bon_livraison_list_item.dart';
import 'package:fes_distribution/ui/common/confirm_dialog.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/loading_view.dart';
import 'package:fes_distribution/ui/common/responsive.dart';
import 'package:fes_distribution/ui/common/shell_app_bar.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

class BlListPage extends ConsumerStatefulWidget {
  const BlListPage({super.key});

  @override
  ConsumerState<BlListPage> createState() => _BlListPageState();
}

class _BlListPageState extends ConsumerState<BlListPage> {
  static const _routeBase = '/ventes/bons-livraison';

  final _searchController = TextEditingController();
  List<BonLivraisonListItem> _rows = [];
  bool _loading = true;
  DateTimeRange? _range;

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
      final to = _range == null
          ? null
          : DateTime(_range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59);
      final rows = await ref.read(bonLivraisonServiceProvider).list(
            search: _searchController.text,
            dateFrom: _range?.start,
            dateTo: to,
          );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await showErrorDialog(context, title: context.s.menuBl, message: '$e');
    }
  }

  Future<void> _open(String path) async {
    await context.push(path);
    if (mounted) await _load();
  }

  Future<bool> _delete(BonLivraisonListItem row) async {
    final title = context.s.menuBl;
    final ok = await showConfirmDialog(
      context,
      title: title,
      message: context.s.deleteBonConfirm(row.bl.numero),
    );
    if (!ok) return false;
    try {
      await ref.read(bonLivraisonServiceProvider).delete(row.bl.id);
      await _load();
      return true;
    } catch (e) {
      if (mounted) await showErrorDialog(context, title: title, message: '$e');
      return false;
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() => _range = picked);
    await _load();
  }

  Widget _statusChip(BuildContext context, BonLivraisonListItem row) {
    final s = context.s;
    final paid = row.bl.estPayee;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (paid ? AppColors.brand : AppColors.danger).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        paid ? s.statusPaye : s.statusNonPaye,
        style: TextStyle(
          color: paid ? AppColors.brand : AppColors.danger,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Scaffold(
      appBar: ShellAppBar(
        title: s.menuBl,
        actions: [
          IconButton(
            tooltip: s.filterDate,
            icon: const Icon(Icons.date_range),
            onPressed: _pickRange,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open('$_routeBase/new'),
        icon: const Icon(Icons.add),
        label: Text(s.actionNew),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: s.searchBl,
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
          if (_range != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: InputChip(
                  avatar: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    '${dateFormat.format(_range!.start)} — ${dateFormat.format(_range!.end)}',
                  ),
                  deleteButtonTooltipMessage: s.clearFilter,
                  onDeleted: () {
                    setState(() => _range = null);
                    _load();
                  },
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? LoadingView(message: s.loading)
                : _rows.isEmpty
                    ? Center(
                        child: Text(
                          s.emptyBl,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: isMobile(context)
                            ? _buildMobile(context)
                            : _buildDesktop(context),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: _rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final row = _rows[index];
        return Dismissible(
          key: ValueKey(row.bl.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _delete(row),
          background: Container(
            alignment: AlignmentDirectional.centerEnd,
            padding: const EdgeInsetsDirectional.only(end: 20),
            color: AppColors.danger,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: const CircleAvatar(
                backgroundColor: AppColors.brandSoft,
                child: Icon(Icons.local_shipping_outlined, color: AppColors.brand),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.bl.numero,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  _statusChip(context, row),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.vendeurNom.isEmpty
                        ? row.clientNom
                        : '${row.clientNom} · ${row.vendeurNom}',
                  ),
                  Text(dateFormat.format(row.bl.date)),
                  Text(
                    formatMoney(row.bl.totalTtc),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open('$_routeBase/${row.bl.id}'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final s = context.s;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              headingRowColor: WidgetStateProperty.all(AppColors.brandSoft),
              columns: [
                DataColumn(label: Text(s.colNumero)),
                DataColumn(label: Text(s.fieldClient)),
                DataColumn(label: Text(s.fieldVendeur)),
                DataColumn(label: Text(s.fieldDate)),
                DataColumn(label: Text(s.colTotalTtc), numeric: true),
                DataColumn(label: Text(s.colReste), numeric: true),
                DataColumn(label: Text(s.colStatut)),
                const DataColumn(label: SizedBox.shrink()),
              ],
              rows: [
                for (final row in _rows)
                  DataRow(
                    onSelectChanged: (_) => _open('$_routeBase/${row.bl.id}'),
                    cells: [
                      DataCell(Text(
                        row.bl.numero,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      )),
                      DataCell(Text(row.clientNom)),
                      DataCell(Text(row.vendeurNom)),
                      DataCell(Text(dateFormat.format(row.bl.date))),
                      DataCell(Text(formatMoney(row.bl.totalTtc))),
                      DataCell(Text(formatMoney(row.resteAPayer))),
                      DataCell(_statusChip(context, row)),
                      DataCell(
                        IconButton(
                          tooltip: s.actionDelete,
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _delete(row),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

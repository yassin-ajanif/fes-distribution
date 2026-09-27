import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/business/models/facture_list_item.dart';
import 'package:fes_distribution/ui/common/confirm_dialog.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/loading_view.dart';
import 'package:fes_distribution/ui/common/responsive.dart';
import 'package:fes_distribution/ui/common/shell_app_bar.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

class FactureListPage extends ConsumerStatefulWidget {
  const FactureListPage({super.key});

  @override
  ConsumerState<FactureListPage> createState() => _FactureListPageState();
}

class _FactureListPageState extends ConsumerState<FactureListPage> {
  static const _routeBase = '/ventes/factures';

  final _searchController = TextEditingController();
  List<FactureListItem> _rows = [];
  bool _loading = true;
  DateTimeRange? _range;

  /// null = all, false = unpaid, true = paid.
  bool? _payee;

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
      final rows = await ref.read(factureServiceProvider).list(
            search: _searchController.text,
            dateFrom: _range?.start,
            dateTo: to,
            estPayee: _payee,
          );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await showErrorDialog(context, title: context.s.menuFactures, message: '$e');
    }
  }

  Future<void> _open(String path) async {
    await context.push(path);
    if (mounted) await _load();
  }

  Future<bool> _delete(FactureListItem row) async {
    final title = context.s.menuFactures;
    final ok = await showConfirmDialog(
      context,
      title: title,
      message: context.s.deleteBonConfirm(row.facture.numero),
    );
    if (!ok) return false;
    try {
      await ref.read(factureServiceProvider).delete(row.facture.id);
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

  Widget _statusChip(BuildContext context, FactureListItem row) {
    final s = context.s;
    final paid = row.facture.estPayee;
    final color = paid
        ? AppColors.brand
        : row.isOverdue
            ? AppColors.danger
            : Colors.orange.shade800;
    final label = paid
        ? s.statusPaye
        : row.isOverdue
            ? s.statusEnRetard
            : s.statusNonPaye;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Scaffold(
      appBar: ShellAppBar(
        title: s.menuFactures,
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
                hintText: s.searchFacture,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 0, label: Text(s.filterAll)),
                    ButtonSegment(value: 1, label: Text(s.statusNonPaye)),
                    ButtonSegment(value: 2, label: Text(s.statusPaye)),
                  ],
                  selected: {_payee == null ? 0 : (_payee! ? 2 : 1)},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) {
                    setState(() => _payee = switch (v.first) {
                          1 => false,
                          2 => true,
                          _ => null,
                        });
                    _load();
                  },
                ),
                if (_range != null)
                  InputChip(
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
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? LoadingView(message: s.loading)
                : _rows.isEmpty
                    ? Center(
                        child: Text(
                          s.emptyFacture,
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
    final s = context.s;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: _rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final row = _rows[index];
        return Dismissible(
          key: ValueKey(row.facture.id),
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
                child: Icon(Icons.description_outlined, color: AppColors.brand),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.facture.numero,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  _statusChip(context, row),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.clientNom),
                  Text(
                    '${dateFormat.format(row.facture.date)} · '
                    '${s.colEcheance} ${dateFormat.format(row.facture.dateEcheance)}',
                  ),
                  if (row.blNumeros.isNotEmpty) Text(row.blNumeros.join(', ')),
                  Text(
                    formatMoney(row.facture.totalTtc),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open('$_routeBase/${row.facture.id}'),
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
                DataColumn(label: Text(s.fieldDate)),
                DataColumn(label: Text(s.colEcheance)),
                DataColumn(label: Text(s.colBls)),
                DataColumn(label: Text(s.colTotalTtc), numeric: true),
                DataColumn(label: Text(s.colStatut)),
                const DataColumn(label: SizedBox.shrink()),
              ],
              rows: [
                for (final row in _rows)
                  DataRow(
                    onSelectChanged: (_) => _open('$_routeBase/${row.facture.id}'),
                    cells: [
                      DataCell(Text(
                        row.facture.numero,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      )),
                      DataCell(Text(row.clientNom)),
                      DataCell(Text(dateFormat.format(row.facture.date))),
                      DataCell(Text(dateFormat.format(row.facture.dateEcheance))),
                      DataCell(Text(row.blNumeros.join(', '))),
                      DataCell(Text(formatMoney(row.facture.totalTtc))),
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

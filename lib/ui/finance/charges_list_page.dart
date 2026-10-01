import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/business/models/charge_list_item.dart';
import 'package:fes_distribution/ui/common/confirm_dialog.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/loading_view.dart';
import 'package:fes_distribution/ui/common/responsive.dart';
import 'package:fes_distribution/ui/common/shell_app_bar.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

/// Expenses (`Charges`): what the company spends, one row per charge.
class ChargesListPage extends ConsumerStatefulWidget {
  const ChargesListPage({super.key});

  @override
  ConsumerState<ChargesListPage> createState() => _ChargesListPageState();
}

class _ChargesListPageState extends ConsumerState<ChargesListPage> {
  static const _routeBase = '/admin/charges';

  final _searchController = TextEditingController();
  List<ChargeListItem> _rows = [];
  double _total = 0;
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
      final service = ref.read(chargeServiceProvider);
      final to = _range == null
          ? null
          : DateTime(
              _range!.end.year,
              _range!.end.month,
              _range!.end.day,
              23,
              59,
              59,
            );
      final rows = await service.list(
        search: _searchController.text,
        dateFrom: _range?.start,
        dateTo: to,
      );
      // The header total follows the date filter but not the search box: it
      // answers "how much did I spend in this period".
      final total = await service.total(dateFrom: _range?.start, dateTo: to);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _total = total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await showErrorDialog(
        context,
        title: context.s.menuCharges,
        message: '$e',
      );
    }
  }

  Future<void> _open(String path) async {
    await context.push(path);
    if (mounted) await _load();
  }

  Future<bool> _delete(ChargeListItem row) async {
    final s = context.s;
    final ok = await showConfirmDialog(
      context,
      title: s.menuCharges,
      message: s.deleteChargeConfirm(row.charge.libelle),
    );
    if (!ok) return false;
    try {
      await ref.read(chargeServiceProvider).delete(row.charge.id);
      await _load();
      return true;
    } catch (e) {
      if (mounted) await showErrorDialog(context, title: s.menuCharges, message: '$e');
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

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Scaffold(
      appBar: ShellAppBar(
        title: s.menuCharges,
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
                hintText: s.searchCharge,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.totalCharges,
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ),
                    Text(
                      formatMoney(_total),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? LoadingView(message: s.loading)
                : _rows.isEmpty
                ? Center(
                    child: Text(
                      s.emptyCharges,
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
          key: ValueKey(row.charge.id),
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: const CircleAvatar(
                backgroundColor: AppColors.dangerSoft,
                child: Icon(Icons.money_off_outlined, color: AppColors.danger),
              ),
              title: Text(
                row.charge.libelle,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.typeNom),
                  Text(dateFormat.format(row.charge.date)),
                  if (row.charge.note.isNotEmpty)
                    Text(row.charge.note, overflow: TextOverflow.ellipsis),
                  Text(
                    formatMoney(row.charge.montantTtc),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open('$_routeBase/${row.charge.id}'),
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
                DataColumn(label: Text(s.fieldLibelle)),
                DataColumn(label: Text(s.fieldTypeCharge)),
                DataColumn(label: Text(s.fieldDate)),
                DataColumn(label: Text(s.fieldNote)),
                DataColumn(label: Text(s.colMontantTtc), numeric: true),
                const DataColumn(label: SizedBox.shrink()),
              ],
              rows: [
                for (final row in _rows)
                  DataRow(
                    onSelectChanged: (_) =>
                        _open('$_routeBase/${row.charge.id}'),
                    cells: [
                      DataCell(
                        Text(
                          row.charge.libelle,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(Text(row.typeNom)),
                      DataCell(Text(dateFormat.format(row.charge.date))),
                      DataCell(
                        SizedBox(
                          width: 200,
                          child: Text(
                            row.charge.note,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(formatMoney(row.charge.montantTtc))),
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

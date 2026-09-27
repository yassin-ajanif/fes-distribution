import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/ui/common/confirm_dialog.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/loading_view.dart';
import 'package:fes_distribution/ui/common/responsive.dart';
import 'package:fes_distribution/ui/common/shell_app_bar.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/personnel/widgets/personnel_document_edit_page.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

class _Row {
  const _Row({
    required this.id,
    required this.numero,
    required this.date,
    required this.vendeur,
    required this.depot,
    required this.note,
  });

  final int id;
  final String numero;
  final DateTime date;
  final String vendeur;
  final String depot;
  final String note;
}

class PersonnelDocumentListPage extends ConsumerStatefulWidget {
  const PersonnelDocumentListPage({super.key, required this.kind});

  final PersonnelDocKind kind;

  @override
  ConsumerState<PersonnelDocumentListPage> createState() =>
      _PersonnelDocumentListPageState();
}

class _PersonnelDocumentListPageState
    extends ConsumerState<PersonnelDocumentListPage> {
  final _searchController = TextEditingController();
  List<_Row> _rows = [];
  bool _loading = true;
  DateTimeRange? _range;

  bool get _isCharge => widget.kind == PersonnelDocKind.charge;
  String get _routeBase =>
      _isCharge ? '/distribution/bons-charge' : '/distribution/bons-decharge';

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

  String _title(BuildContext context) =>
      _isCharge ? context.s.menuBonCharge : context.s.menuBonDecharge;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final search = _searchController.text;
      final from = _range?.start;
      final to = _range == null
          ? null
          : DateTime(_range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59);
      final List<_Row> rows;
      if (_isCharge) {
        final items = await ref
            .read(bonChargeServiceProvider)
            .list(search: search, dateFrom: from, dateTo: to);
        rows = [
          for (final i in items)
            _Row(
              id: i.bon.id,
              numero: i.bon.numero,
              date: i.bon.date,
              vendeur: i.assignedToNom,
              depot: i.depotNom,
              note: i.bon.note,
            ),
        ];
      } else {
        final items = await ref
            .read(bonDechargeServiceProvider)
            .list(search: search, dateFrom: from, dateTo: to);
        rows = [
          for (final i in items)
            _Row(
              id: i.bon.id,
              numero: i.bon.numero,
              date: i.bon.date,
              vendeur: i.assignedToNom,
              depot: i.depotNom,
              note: i.bon.note,
            ),
        ];
      }
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await showErrorDialog(context, title: _title(context), message: '$e');
    }
  }

  Future<void> _open(String path) async {
    await context.push(path);
    if (mounted) await _load();
  }

  Future<bool> _delete(_Row row) async {
    final title = _title(context);
    final ok = await showConfirmDialog(
      context,
      title: title,
      message: context.s.deleteBonConfirm(row.numero),
    );
    if (!ok) return false;
    try {
      if (_isCharge) {
        await ref.read(bonChargeServiceProvider).delete(row.id);
      } else {
        await ref.read(bonDechargeServiceProvider).delete(row.id);
      }
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

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Scaffold(
      appBar: ShellAppBar(
        title: _title(context),
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
                hintText: s.searchBon,
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
                          _isCharge ? s.emptyBonCharge : s.emptyBonDecharge,
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
          key: ValueKey(row.id),
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
              leading: CircleAvatar(
                backgroundColor: AppColors.brandSoft,
                child: Icon(
                  _isCharge ? Icons.upload_outlined : Icons.download_outlined,
                  color: AppColors.brand,
                ),
              ),
              title: Text(
                row.numero,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${row.vendeur} · ${row.depot}'),
                  Text(dateFormat.format(row.date)),
                  if (row.note.isNotEmpty) Text(row.note),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open('$_routeBase/${row.id}'),
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
                DataColumn(label: Text(s.fieldVendeur)),
                DataColumn(label: Text(s.fieldDepot)),
                DataColumn(label: Text(s.fieldDate)),
                DataColumn(label: Text(s.note)),
                const DataColumn(label: SizedBox.shrink()),
              ],
              rows: [
                for (final row in _rows)
                  DataRow(
                    onSelectChanged: (_) => _open('$_routeBase/${row.id}'),
                    cells: [
                      DataCell(Text(
                        row.numero,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      )),
                      DataCell(Text(row.vendeur)),
                      DataCell(Text(row.depot)),
                      DataCell(Text(dateFormat.format(row.date))),
                      DataCell(Text(row.note)),
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

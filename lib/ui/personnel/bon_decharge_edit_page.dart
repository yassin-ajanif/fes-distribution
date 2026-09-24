import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/business/helpers/document_totals.dart';
import 'package:fes_distribution/business/models/personnel_document_line.dart';
import 'package:fes_distribution/business/services/stock_movement_service.dart';
import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/common/confirm_dialog.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/loading_view.dart';
import 'package:fes_distribution/ui/common/responsive.dart';
import 'package:fes_distribution/ui/personnel/widgets/document_lines_table.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';

class BonDechargeEditPage extends ConsumerStatefulWidget {
  const BonDechargeEditPage({super.key, this.bonId});

  final int? bonId;

  @override
  ConsumerState<BonDechargeEditPage> createState() =>
      _BonDechargeEditPageState();
}

class _BonDechargeEditPageState extends ConsumerState<BonDechargeEditPage> {
  bool _loading = true;
  bool _saving = false;

  String _numero = '(nouveau)';
  DateTime _date = DateTime.now();
  final _noteController = TextEditingController();
  int? _assignedToUserId;
  int? _depotLocationId;
  int? _selectedLineIndex;

  List<User> _vendeurs = [];
  List<StockLocation> _depots = [];
  List<Produit> _produits = [];
  List<PersonnelDocumentLine> _lines = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await ref.read(userServiceProvider).listActiveVendeurs();
      final depots =
          await ref.read(stockLocationServiceProvider).getActivePhysicalLocations();
      final produits = await ref.read(produitServiceProvider).listActive();

      if (widget.bonId == null) {
        final defaultDepot =
            await ref.read(stockLocationServiceProvider).getOrCreateDefaultDepot();
        setState(() {
          _vendeurs = users;
          _depots = depots;
          _produits = produits;
          _assignedToUserId = users.isNotEmpty ? users.first.id : null;
          _depotLocationId = defaultDepot.id;
          _lines = [];
          _numero = '(nouveau)';
          _date = DateTime.now();
          _noteController.clear();
          _loading = false;
        });
        return;
      }

      final data =
          await ref.read(bonDechargeServiceProvider).getById(widget.bonId!);
      if (data == null) throw StateError('Bon introuvable.');
      setState(() {
        _vendeurs = users;
        _depots = depots;
        _produits = produits;
        _numero = data.bon.numero;
        _date = data.bon.date;
        _noteController.text = data.bon.note;
        _assignedToUserId = data.bon.assignedToUserId;
        _depotLocationId = data.bon.depotLocationId;
        _lines = data.lines;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        await showErrorDialog(context, title: 'Bon décharge', message: '$e');
        context.pop();
      }
    }
  }

  DocumentTotals get _totals => DocumentTotals.fromLines(_lines);

  void _addProduct(Produit p) {
    final existing = _lines.cast<PersonnelDocumentLine?>().firstWhere(
          (l) => l?.produitId == p.id,
          orElse: () => null,
        );
    setState(() {
      if (existing != null) {
        existing.quantite += 1;
      } else {
        _lines.add(
          PersonnelDocumentLine(
            produitId: p.id,
            reference: p.reference,
            designation: p.designation,
            quantite: 1,
            prixUnitaireHt: p.prixVenteHT,
            tauxTva: p.tauxTVA,
          ),
        );
      }
    });
  }

  Future<void> _save() async {
    if (_assignedToUserId == null) {
      await showErrorDialog(
        context,
        title: 'Bon décharge',
        message: 'Sélectionnez un vendeur.',
      );
      return;
    }
    if (_depotLocationId == null) {
      await showErrorDialog(
        context,
        title: 'Bon décharge',
        message: 'Sélectionnez un dépôt.',
      );
      return;
    }
    if (_lines.every((l) => l.produitId <= 0 || l.quantite <= 0)) {
      await showErrorDialog(
        context,
        title: 'Bon décharge',
        message: 'Ajoutez au moins une ligne.',
      );
      return;
    }
    if (DocumentTotals.isEffectivelyZero(_totals.totalTtc)) {
      await showErrorDialog(
        context,
        title: 'Bon décharge',
        message: 'Le total TTC ne peut pas être nul.',
      );
      return;
    }

    final user = await ref.read(userServiceProvider).getById(_assignedToUserId!);
    if (user == null) throw StateError('Vendeur introuvable.');
    final virtualLoc =
        await ref.read(stockLocationServiceProvider).getOrCreateVirtualForUser(user);

    final stockLines = _lines
        .where((l) => l.produitId > 0 && l.quantite > 0)
        .map((l) => (produitId: l.produitId, quantite: l.quantite));

    final shortages =
        await ref.read(stockMovementServiceProvider).getOutboundShortages(
              fromLocationId: virtualLoc.id,
              desiredOutboundLines: stockLines,
              origineType: StockMovementService.origineTypeBonDecharge,
              origineId: widget.bonId,
            );
    if (shortages.isNotEmpty) {
      final ok = await showStockShortageDialog(
        context,
        lines: shortages
            .map(
              (s) =>
                  '${s.reference} — demandé ${formatQty(s.requested)}, dispo ${formatQty(s.available)}',
            )
            .toList(),
      );
      if (!ok) return;
    }

    setState(() => _saving = true);
    try {
      final id = await ref.read(bonDechargeWorkflowProvider).save(
            id: widget.bonId,
            assignedToUserId: _assignedToUserId!,
            depotLocationId: _depotLocationId!,
            date: _date,
            note: _noteController.text,
            lines: _lines,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bon de décharge enregistré.')),
      );
      if (widget.bonId == null) {
        context.go('/distribution/bons-decharge/$id');
      } else {
        await _load();
      }
    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, title: 'Bon décharge', message: '$e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (widget.bonId == null) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Bon décharge',
      message: 'Supprimer ce bon ?',
    );
    if (!ok) return;

    setState(() => _saving = true);
    try {
      await ref.read(bonDechargeWorkflowProvider).delete(widget.bonId!);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, title: 'Bon décharge', message: '$e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Widget _buildHeaderFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          initialValue: _assignedToUserId,
          decoration: const InputDecoration(labelText: 'Vendeur'),
          items: _vendeurs
              .map((u) => DropdownMenuItem(value: u.id, child: Text(u.fullName)))
              .toList(),
          onChanged: (v) => setState(() => _assignedToUserId = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _depotLocationId,
          decoration: const InputDecoration(labelText: 'Dépôt'),
          items: _depots
              .map((l) => DropdownMenuItem(value: l.id, child: Text(l.nom)))
              .toList(),
          onChanged: (v) => setState(() => _depotLocationId = v),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today, size: 18),
          label: Text(dateFormat.format(_date)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          decoration: const InputDecoration(labelText: 'Note'),
          maxLines: 2,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(widget.bonId == null ? 'Nouveau bon de décharge' : _numero),
        actions: [
          if (widget.bonId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Enregistrer'),
          ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildHeaderFields(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ajouter un produit',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          Autocomplete<Produit>(
                            optionsBuilder: (text) {
                              final t = text.text.toLowerCase();
                              if (t.isEmpty) return _produits.take(20);
                              return _produits.where(
                                (p) =>
                                    p.reference.toLowerCase().contains(t) ||
                                    p.designation.toLowerCase().contains(t),
                              );
                            },
                            displayStringForOption: (p) =>
                                '${p.reference} — ${p.designation}',
                            onSelected: _addProduct,
                            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  hintText: 'Rechercher un produit…',
                                  prefixIcon: Icon(Icons.search),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!mobile) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: _selectedLineIndex == null
                              ? null
                              : () {
                                  setState(() {
                                    _lines.removeAt(_selectedLineIndex!);
                                    _selectedLineIndex = null;
                                  });
                                },
                          child: const Text('Supprimer la ligne'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  DocumentLinesTable(
                    lines: _lines,
                    selectedIndex: _selectedLineIndex,
                    onSelect: (i) => setState(() => _selectedLineIndex = i),
                    onChanged: (i, line) => setState(() => _lines[i] = line),
                    onRemoveAt: (i) {
                      setState(() {
                        _lines.removeAt(i);
                        _selectedLineIndex = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Total HT : ${formatMoney(_totals.totalHt)}'),
                            Text('Total TVA : ${formatMoney(_totals.totalTva)}'),
                            Text(
                              'Total TTC : ${formatMoney(_totals.totalTtc)}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

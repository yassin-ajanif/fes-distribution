import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/common/app_bar_save_button.dart';
import 'package:fes_distribution/ui/common/confirm_dialog.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/loading_view.dart';
import 'package:fes_distribution/ui/common/responsive.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

/// Create or edit a single expense (`Charge`).
class ChargeEditPage extends ConsumerStatefulWidget {
  const ChargeEditPage({super.key, this.chargeId});

  final int? chargeId;

  @override
  ConsumerState<ChargeEditPage> createState() => _ChargeEditPageState();
}

class _ChargeEditPageState extends ConsumerState<ChargeEditPage> {
  bool _loading = true;
  bool _saving = false;

  final _libelleController = TextEditingController();
  final _montantController = TextEditingController();
  final _noteController = TextEditingController();
  final _newTypeController = TextEditingController();

  DateTime _date = DateTime.now();
  int? _typeId;
  List<TypesCharge> _types = [];

  bool get _isNew => widget.chargeId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _libelleController.dispose();
    _montantController.dispose();
    _noteController.dispose();
    _newTypeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final service = ref.read(chargeServiceProvider);
      _types = await service.listActiveTypes();
      if (!_isNew) {
        final charge = await service.getById(widget.chargeId!);
        if (charge == null) throw StateError('Charge introuvable.');
        _libelleController.text = charge.libelle;
        _montantController.text = formatInput(charge.montantTtc);
        _noteController.text = charge.note;
        _date = charge.date;
        if (!_types.any((t) => t.id == charge.typeChargeId)) {
          final t = await service.getTypeById(charge.typeChargeId);
          if (t != null) _types.add(t);
        }
        _typeId = charge.typeChargeId;
      } else {
        _libelleController.clear();
        _montantController.clear();
        _noteController.clear();
        _date = DateTime.now();
        _typeId = _types.isNotEmpty ? _types.first.id : null;
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await showErrorDialog(
        context,
        title: context.s.menuCharges,
        message: '$e',
      );
      if (mounted) context.pop();
    }
  }

  Future<void> _save() async {
    final s = context.s;
    final montant =
        double.tryParse(_montantController.text.replaceAll(',', '.')) ?? 0;

    if (_typeId == null) {
      await showErrorDialog(
        context,
        title: s.menuCharges,
        message: s.errSelectTypeCharge,
      );
      return;
    }
    if (_libelleController.text.trim().isEmpty) {
      await showErrorDialog(
        context,
        title: s.menuCharges,
        message: s.errLibelleRequired,
      );
      return;
    }
    if (montant <= 0) {
      await showErrorDialog(
        context,
        title: s.menuCharges,
        message: s.errMontantRequired,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final service = ref.read(chargeServiceProvider);
      await service.save(
        id: widget.chargeId,
        typeChargeId: _typeId!,
        libelle: _libelleController.text,
        date: _date,
        montantTtc: montant,
        note: _noteController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.chargeSaved)));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(context, title: s.menuCharges, message: '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_isNew) return;
    final s = context.s;
    final ok = await showConfirmDialog(
      context,
      title: s.menuCharges,
      message: s.deleteChargeConfirm(_libelleController.text),
    );
    if (!ok) return;
    try {
      await ref.read(chargeServiceProvider).delete(widget.chargeId!);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted)
        await showErrorDialog(context, title: s.menuCharges, message: '$e');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _createType() async {
    final s = context.s;
    _newTypeController.clear();
    final nom = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.newTypeCharge),
        content: TextField(
          controller: _newTypeController,
          decoration: InputDecoration(labelText: s.fieldLibelle),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(_newTypeController.text),
            child: Text(s.actionSave),
          ),
        ],
      ),
    );
    if (nom == null || nom.trim().isEmpty) return;
    try {
      final id = await ref.read(chargeServiceProvider).createType(nom);
      _types = await ref.read(chargeServiceProvider).listActiveTypes();
      if (mounted) {
        setState(() => _typeId = id);
      }
    } catch (e) {
      if (mounted)
        await showErrorDialog(context, title: s.newTypeCharge, message: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final mobile = isMobile(context);

    return Scaffold(
      appBar: AppBar(
        leading: mobile
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
        title: Text(_isNew ? s.chargeNew : s.menuCharges),
        actions: [
          if (!_isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
          AppBarSaveButton(onPressed: _save, saving: _saving),
        ],
      ),
      body: _loading
          ? LoadingView(message: s.loading)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _typeId,
                                  decoration: InputDecoration(
                                    labelText: s.fieldTypeCharge,
                                  ),
                                  items: [
                                    for (final t in _types)
                                      DropdownMenuItem(
                                        value: t.id,
                                        child: Text(t.nom),
                                      ),
                                  ],
                                  onChanged: (v) => setState(() => _typeId = v),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                tooltip: s.newTypeCharge,
                                icon: const Icon(Icons.add),
                                onPressed: _createType,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _libelleController,
                            decoration: InputDecoration(
                              labelText: s.fieldLibelle,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickDate,
                                  icon: const Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                  ),
                                  label: Text(
                                    '${s.fieldDate} : ${dateFormat.format(_date)}',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _montantController,
                            decoration: InputDecoration(
                              labelText: s.fieldMontant,
                              prefixText: 'DH ',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _noteController,
                            maxLines: 3,
                            decoration: InputDecoration(labelText: s.fieldNote),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

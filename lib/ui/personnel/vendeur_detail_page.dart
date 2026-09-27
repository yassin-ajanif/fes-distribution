import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/ui/common/app_bar_save_button.dart';
import 'package:fes_distribution/business/models/vendeur_stock_line.dart';
import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/common/confirm_dialog.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/loading_view.dart';
import 'package:fes_distribution/ui/common/responsive.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

class VendeurDetailPage extends ConsumerStatefulWidget {
  const VendeurDetailPage({super.key, this.userId});

  final int? userId;

  bool get isNew => userId == null;

  @override
  ConsumerState<VendeurDetailPage> createState() => _VendeurDetailPageState();
}

class _VendeurDetailPageState extends ConsumerState<VendeurDetailPage> {
  bool _loading = true;
  bool _saving = false;
  User? _user;

  final _nomController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _actif = true;

  List<VendeurStockLine> _stockLines = [];
  double _qtyTotal = 0;
  double _valVenteTtc = 0;
  bool _loadingStock = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (widget.isNew) {
        setState(() {
          _user = null;
          _nomController.clear();
          _phoneController.clear();
          _actif = true;
          _stockLines = [];
          _loading = false;
        });
        return;
      }

      final user = await ref.read(userServiceProvider).getById(widget.userId!);
      if (user == null) throw StateError('Vendeur introuvable.');
      setState(() {
        _user = user;
        _nomController.text = user.fullName;
        _phoneController.text = user.phone;
        _actif = user.actif;
        _loading = false;
      });
      await _loadStock(user);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        await showErrorDialog(context, title: 'Vendeurs', message: '$e');
        context.pop();
      }
    }
  }

  Future<void> _loadStock(User user) async {
    setState(() => _loadingStock = true);
    try {
      final service = ref.read(vendeurStockServiceProvider);
      final lines = await service.getStockLines(user);
      final totals = await service.getStockTotals(user);
      if (!mounted) return;
      setState(() {
        _stockLines = lines;
        _qtyTotal = totals.qtyTotal;
        _valVenteTtc = totals.valVenteTtc;
        _loadingStock = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingStock = false);
    }
  }

  bool get _ficheEditable => widget.isNew || _user != null;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final service = ref.read(userServiceProvider);
      if (widget.isNew) {
        await service.createVendeur(
          fullName: _nomController.text,
          phone: _phoneController.text,
          actif: _actif,
        );
      } else {
        await service.updateVendeur(
          id: _user!.id,
          fullName: _nomController.text,
          phone: _phoneController.text,
          actif: _actif,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vendeur enregistré.')),
      );
      context.pop(true);
    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, title: 'Vendeurs', message: '$e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_user == null) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer le vendeur',
      message: 'Supprimer ${_user!.fullName} ?',
    );
    if (!ok) return;

    setState(() => _saving = true);
    try {
      await ref.read(userServiceProvider).deleteVendeur(_user!.id);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, title: 'Vendeurs', message: '$e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);

    return Scaffold(
      appBar: AppBar(
        leading: mobile
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
        title: Text(widget.isNew ? 'Nouveau vendeur' : (_user?.fullName ?? 'Vendeur')),
        actions: [
          if (_user != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
          AppBarSaveButton(
            onPressed: _ficheEditable ? _save : null,
            saving: _saving,
          ),
        ],
      ),
      body: _loading
          ? const LoadingView(message: 'Chargement…')
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
                          TextField(
                            controller: _nomController,
                            enabled: _ficheEditable,
                            decoration: const InputDecoration(labelText: 'Nom complet'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _phoneController,
                            enabled: _ficheEditable,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(labelText: 'Téléphone'),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Actif'),
                            value: _actif,
                            onChanged:
                                _ficheEditable ? (v) => setState(() => _actif = v) : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_user != null) ...[
                    const SizedBox(height: 20),
                    Text('Solde stock', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _SummaryChip(label: 'Qté totale', value: formatQty(_qtyTotal)),
                        _SummaryChip(
                          label: 'Val. vente TTC',
                          value: formatMoney(_valVenteTtc),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loadingStock)
                      const LoadingView()
                    else if (_stockLines.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Aucun stock chez ce vendeur.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      )
                    else
                      ..._stockLines.map(
                        (line) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(line.designation),
                            subtitle: Text(line.reference),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(formatQty(line.quantite)),
                                Text(
                                  formatMoney(line.valVenteTtc),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AppColors.muted, fontSize: 12)),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

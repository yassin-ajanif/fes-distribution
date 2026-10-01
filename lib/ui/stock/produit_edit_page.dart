import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fes_distribution/ui/common/app_bar_save_button.dart';
import 'package:fes_distribution/business/models/produit_input.dart';
import 'package:fes_distribution/db/app_database.dart';
import 'package:fes_distribution/ui/common/confirm_dialog.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/loading_view.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/providers/service_providers.dart';
import 'package:fes_distribution/ui/stock/barcode_scanner_page.dart';

class ProduitEditPage extends ConsumerStatefulWidget {
  const ProduitEditPage({super.key, this.produitId});

  final int? produitId;

  @override
  ConsumerState<ProduitEditPage> createState() => _ProduitEditPageState();
}

class _ProduitEditPageState extends ConsumerState<ProduitEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _reference = TextEditingController();
  final _designation = TextEditingController();
  final _codeBarre = TextEditingController();
  final _unite = TextEditingController(text: 'U');
  final _prixAchat = TextEditingController(text: '0');
  final _prixVente = TextEditingController(text: '0');
  final _tva = TextEditingController(text: '20');
  final _stockMin = TextEditingController(text: '0');
  final _stockToAdd = TextEditingController();

  List<Category> _categories = [];
  List<StockLocation> _depots = [];
  Map<int, double> _stockByDepot = {};
  int? _depotId;
  int? _categorieId;
  bool _actif = true;
  bool _loading = true;
  bool _saving = false;

  /// Bytes of a newly picked photo, waiting to be saved.
  Uint8List? _pickedImage;

  /// Photo already stored on the product, shown when nothing new was picked.
  Uint8List? _storedImage;

  /// Whether the user asked to drop the stored photo.
  bool _clearImage = false;

  final ImagePicker _picker = ImagePicker();

  /// Currently displayed photo: the new pick wins over the stored one.
  Uint8List? get _displayImage =>
      _clearImage ? null : (_pickedImage ?? _storedImage);

  bool get _isNew => widget.produitId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _reference,
      _designation,
      _codeBarre,
      _unite,
      _prixAchat,
      _prixVente,
      _tva,
      _stockMin,
      _stockToAdd,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final categories = await ref.read(categorieServiceProvider).listAll();
      final depots = await ref
          .read(stockLocationServiceProvider)
          .getActivePhysicalLocations();
      Produit? produit;
      final stockByDepot = <int, double>{};
      if (!_isNew) {
        produit = await ref
            .read(produitServiceProvider)
            .getById(widget.produitId!);
        if (produit == null) throw StateError('Produit introuvable.');
        final balance = ref.read(stockBalanceServiceProvider);
        for (final d in depots) {
          stockByDepot[d.id] = await balance.getStock(produit.id, d.id);
        }
      }
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _depots = depots;
        _stockByDepot = stockByDepot;
        _depotId = depots.isNotEmpty ? depots.first.id : null;
        if (produit != null) {
          _reference.text = produit.reference;
          _designation.text = produit.designation;
          _codeBarre.text = produit.codeBarre ?? '';
          _unite.text = produit.unite;
          _prixAchat.text = _num(produit.prixAchatHT);
          _prixVente.text = _num(produit.prixVenteHT);
          _tva.text = _num(produit.tauxTVA);
          _stockMin.text = _num(produit.stockMinimum);
          _categorieId = produit.categorieId;
          _actif = produit.actif;
          _storedImage = produit.imageData;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(
        context,
        title: context.s.menuProduits,
        message: '$e',
      );
      if (mounted) context.pop();
    }
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  static double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? context.s.requiredField : null;

  String? _number(String? v) {
    final parsed = _parse(v ?? '');
    if (parsed == null || parsed < 0) return context.s.invalidNumber;
    return null;
  }

  double get _currentDepotStock =>
      _depotId == null ? 0 : (_stockByDepot[_depotId] ?? 0);

  String? _validateStockToAdd(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return null;
    final delta = _parse(text);
    if (delta == null) return context.s.invalidNumber;
    if (_currentDepotStock + delta < 0) return context.s.stockNegative;
    return null;
  }

  Future<void> _addCategorie() async {
    final s = context.s;
    final controller = TextEditingController();
    final nom = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.newCategorie),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: s.fieldName),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(s.actionSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (nom == null || nom.trim().isEmpty) return;

    try {
      final id = await ref.read(categorieServiceProvider).create(nom);
      final categories = await ref.read(categorieServiceProvider).listAll();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _categorieId = id;
      });
    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, title: s.fieldCategorie, message: '$e');
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final s = context.s;
    try {
      final file = await _picker.pickImage(
        source: source,
        // Ask the platform picker to downscale before we even see the bytes;
        // the service then enforces the final cap.
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (file == null) return;

      final raw = await file.readAsBytes();
      final prepared = await ref.read(produitImageServiceProvider).prepare(raw);
      if (!mounted) return;
      setState(() {
        _pickedImage = prepared;
        _clearImage = false;
      });
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(context, title: s.fieldPhoto, message: '$e');
    }
  }

  Future<void> _chooseImageSource() async {
    final s = context.s;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(s.photoFromCamera),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(s.photoFromGallery),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    await _pickImage(source);
  }

  void _removeImage() {
    setState(() {
      _pickedImage = null;
      _storedImage = null;
      _clearImage = true;
    });
  }

  Future<void> _scanBarcode() async {
    final s = context.s;
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (code == null || !mounted) return;

    setState(() => _codeBarre.text = code);

    // If the code is already attached to a product, tell the user right away
    // rather than letting the save fail on the uniqueness check.
    try {
      final existing = await ref
          .read(produitServiceProvider)
          .findByCodeBarre(code);
      if (!mounted || existing == null) return;
      if (existing.id == widget.produitId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.barcodeFound(existing.designation))),
      );
    } catch (_) {
      // Lookup is best-effort; saving still validates uniqueness.
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final s = context.s;

    final input = ProduitInput(
      reference: _reference.text,
      designation: _designation.text,
      codeBarre: _codeBarre.text,
      unite: _unite.text,
      prixAchatHT: _parse(_prixAchat.text) ?? 0,
      prixVenteHT: _parse(_prixVente.text) ?? 0,
      tauxTVA: _parse(_tva.text) ?? 0,
      stockMinimum: _parse(_stockMin.text) ?? 0,
      categorieId: _categorieId,
      imageData: _pickedImage,
      clearImage: _clearImage,
      actif: _actif,
    );

    setState(() => _saving = true);
    try {
      final service = ref.read(produitServiceProvider);
      final int produitId;
      if (_isNew) {
        produitId = await service.create(input);
      } else {
        produitId = widget.produitId!;
        await service.update(produitId, input);
      }
      final delta = _parse(_stockToAdd.text) ?? 0;
      if (delta != 0 && _depotId != null) {
        await ref
            .read(stockMovementServiceProvider)
            .applyAdjustment(
              produitId: produitId,
              locationId: _depotId!,
              delta: delta,
              note: s.produitStockMotif,
            );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.produitSaved)));
      context.pop();
    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, title: s.menuProduits, message: '$e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _numberField(TextEditingController c, String label) {
    return TextFormField(
      controller: c,
      decoration: InputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      validator: _number,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(_isNew ? s.produitNew : _designation.text),
        actions: [
          AppBarSaveButton(onPressed: _loading ? null : _save, saving: _saving),
        ],
      ),
      body: _loading
          ? LoadingView(message: s.loading)
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Section(
                    title: s.fieldPhoto,
                    children: [
                      _PhotoField(
                        image: _displayImage,
                        onPick: _loading ? null : _chooseImageSource,
                        onRemove: _displayImage == null ? null : _removeImage,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: s.sectionIdentification,
                    children: [
                      TextFormField(
                        controller: _reference,
                        decoration: InputDecoration(
                          labelText: '${s.fieldReference} *',
                        ),
                        validator: _required,
                        textInputAction: TextInputAction.next,
                      ),
                      TextFormField(
                        controller: _designation,
                        decoration: InputDecoration(
                          labelText: '${s.fieldDesignation} *',
                        ),
                        validator: _required,
                        textInputAction: TextInputAction.next,
                      ),
                      TextFormField(
                        controller: _codeBarre,
                        decoration: InputDecoration(
                          labelText: s.fieldCodeBarre,
                          suffixIcon: IconButton(
                            tooltip: s.scanBarcode,
                            icon: const Icon(Icons.qr_code_scanner),
                            onPressed: _loading ? null : _scanBarcode,
                          ),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      TextFormField(
                        controller: _unite,
                        decoration: InputDecoration(labelText: s.fieldUnite),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              initialValue: _categorieId,
                              decoration: InputDecoration(
                                labelText: s.fieldCategorie,
                              ),
                              items: [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text(s.noCategorie),
                                ),
                                for (final c in _categories)
                                  DropdownMenuItem<int?>(
                                    value: c.id,
                                    child: Text(c.nom),
                                  ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _categorieId = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: s.newCategorie,
                            icon: const Icon(Icons.add),
                            onPressed: _addCategorie,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: s.sectionPrix,
                    children: [
                      _numberField(_prixAchat, s.fieldPrixAchat),
                      _numberField(_prixVente, s.fieldPrixVente),
                      _numberField(_tva, s.fieldTva),
                      ValueListenableBuilder(
                        valueListenable: _prixVente,
                        builder: (context, _, __) => ValueListenableBuilder(
                          valueListenable: _tva,
                          builder: (context, _, __) {
                            final ht = _parse(_prixVente.text) ?? 0;
                            final tva = _parse(_tva.text) ?? 0;
                            return Text(
                              'TTC : ${formatMoney(ht * (1 + tva / 100))}',
                              style: Theme.of(context).textTheme.titleSmall,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: s.menuStock,
                    children: [
                      _numberField(_stockMin, s.fieldStockMin),
                      if (_depots.isNotEmpty) ...[
                        DropdownButtonFormField<int>(
                          initialValue: _depotId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: s.locationPhysical,
                            prefixIcon: const Icon(Icons.warehouse_outlined),
                          ),
                          items: [
                            for (final d in _depots)
                              DropdownMenuItem(
                                value: d.id,
                                child: Text(
                                  _isNew
                                      ? d.nom
                                      : '${d.nom} (${formatQty(_stockByDepot[d.id] ?? 0)})',
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() => _depotId = v),
                        ),
                        TextFormField(
                          controller: _stockToAdd,
                          decoration: InputDecoration(
                            labelText: s.stockToAdd,
                            prefixIcon: const Icon(Icons.add_box_outlined),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,\-]'),
                            ),
                          ],
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: _validateStockToAdd,
                        ),
                        ValueListenableBuilder(
                          valueListenable: _stockToAdd,
                          builder: (context, _, _) {
                            final before = _currentDepotStock;
                            final after =
                                before + (_parse(_stockToAdd.text) ?? 0);
                            return Text(
                              s.stockBeforeAfter(
                                formatQty(before),
                                formatQty(after),
                              ),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: after < 0
                                        ? Theme.of(context).colorScheme.error
                                        : null,
                                  ),
                            );
                          },
                        ),
                      ],
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(s.fieldActif),
                        value: _actif,
                        onChanged: (v) => setState(() => _actif = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            for (final child in children) ...[
              const SizedBox(height: 12),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// Photo preview with add/replace and remove actions.
class _PhotoField extends StatelessWidget {
  const _PhotoField({
    required this.image,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? image;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 120,
            height: 120,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: image == null
                ? Icon(
                    Icons.image_outlined,
                    size: 40,
                    color: Theme.of(context).colorScheme.outline,
                  )
                : Image.memory(
                    image!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined, size: 40),
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilledButton.tonalIcon(
                onPressed: onPick,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(image == null ? s.photoAdd : s.photoChange),
              ),
              if (onRemove != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(s.photoRemove),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

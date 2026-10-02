import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fes_distribution/business/models/document_line.dart';
import 'package:fes_distribution/ui/common/formatters.dart';
import 'package:fes_distribution/ui/common/product_image.dart';
import 'package:fes_distribution/ui/common/responsive.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

double parseQty(String text) =>
    double.tryParse(text.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.')) ?? 0;

/// Editable document lines.
/// [available] = stock at the source location per product (shown as "Dispo");
/// null hides the column (documents without stock impact, e.g. facture).
/// [editablePrice] lets the user type the unit price (purchase documents).
/// [images] = product photos by product id (see [productImagesById]); adds a
/// photo button per line that opens the image. Null or empty hides it.
///
/// Desktop renders the full grid. On phones each line collapses to a compact
/// header (photo, name, line TTC, expand arrow) and the editable fields only
/// appear once the line is expanded, so a long document is scannable without
/// scrolling through every field.
class DocumentLinesTable extends StatefulWidget {
  const DocumentLinesTable({
    super.key,
    required this.lines,
    required this.onChanged,
    required this.onRemoveAt,
    this.available,
    this.editablePrice = false,
    this.images,
  });

  final List<DocumentLine> lines;
  final void Function(int index, DocumentLine line) onChanged;
  final void Function(int index) onRemoveAt;
  final Map<int, double>? available;
  final bool editablePrice;
  final Map<int, Uint8List>? images;

  @override
  State<DocumentLinesTable> createState() => _DocumentLinesTableState();
}

class _DocumentLinesTableState extends State<DocumentLinesTable> {
  /// Expanded lines, keyed by [DocumentLine.key] rather than index: removing
  /// a line shifts every index after it, the key does not.
  final Set<String> _expanded = {};

  List<DocumentLine> get lines => widget.lines;
  Map<int, double>? get available => widget.available;
  bool get editablePrice => widget.editablePrice;
  Map<int, Uint8List>? get images => widget.images;
  void Function(int index, DocumentLine line) get onChanged =>
      widget.onChanged;
  void Function(int index) get onRemoveAt => widget.onRemoveAt;

  bool get _showImages => images != null && images!.isNotEmpty;

  bool _isExpanded(DocumentLine l) => _expanded.contains(l.key);

  void _toggle(DocumentLine l) => setState(() {
    if (!_expanded.remove(l.key)) _expanded.add(l.key);
  });

  @override
  void didUpdateWidget(covariant DocumentLinesTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Forget lines that are gone, otherwise re-adding a product would come
    // back already expanded.
    final keys = {for (final l in lines) l.key};
    _expanded.removeWhere((k) => !keys.contains(k));
  }

  Widget _imageCell(DocumentLine l) => ProductImageButton(
    reference: l.reference,
    designation: l.designation,
    bytes: images![l.produitId],
  );

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    if (lines.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              s.noLines,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ),
      );
    }
    return isMobile(context) ? _buildMobile(context) : _buildDesktop(context);
  }

  bool _isShort(DocumentLine l) =>
      available != null && l.quantite > (available![l.produitId] ?? 0);

  Widget _dispoText(DocumentLine l, {String Function(String)? label}) {
    final qty = formatQty(available?[l.produitId] ?? 0);
    return Text(
      label == null ? qty : label(qty),
      style: TextStyle(
        color: _isShort(l) ? AppColors.danger : AppColors.muted,
        fontWeight: _isShort(l) ? FontWeight.w600 : null,
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < lines.length; i++)
          Card(
            key: ValueKey('line-${lines[i].key}'),
            margin: const EdgeInsets.only(bottom: 8),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildMobileHeader(context, i),
                if (_isExpanded(lines[i])) _buildMobileDetails(context, i),
              ],
            ),
          ),
      ],
    );
  }

  /// Compact summary row: photo, product name, line TTC and the expand arrow.
  /// Tapping anywhere but the photo or the delete button toggles the detail
  /// panel, so a whole delivery can be reviewed without scrolling per line.
  Widget _buildMobileHeader(BuildContext context, int i) {
    final s = context.s;
    final l = lines[i];
    final short = _isShort(l);
    final expanded = _isExpanded(l);
    final bytes = images?[l.produitId];

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _toggle(l),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
              child: Row(
                children: [
                  if (bytes != null) ...[
                    InkWell(
                      onTap: () => showProductImageDialog(
                        context,
                        reference: l.reference,
                        designation: l.designation,
                        bytes: bytes,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      child: ProductThumbnail(bytes: bytes),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l.designation.isEmpty ? l.reference : l.designation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _mobileSubtitle(context, l),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: short ? AppColors.danger : AppColors.muted,
                            fontSize: Theme.of(
                              context,
                            ).textTheme.bodySmall?.fontSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatMoney(l.montantTtc),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    tooltip: expanded ? s.collapseLine : s.expandLine,
                    icon: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    onPressed: () => _toggle(l),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () => onRemoveAt(i),
        ),
      ],
    );
  }

  String _mobileSubtitle(BuildContext context, DocumentLine l) => [
    if (l.reference.isNotEmpty) l.reference,
    '${context.s.quantity} : ${formatQty(l.quantite)}',
    if (available != null)
      context.s.available(formatQty(available![l.produitId] ?? 0)),
  ].join(' · ');

  Widget _buildMobileDetails(BuildContext context, int i) {
    final s = context.s;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 12, end: 12, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          _TextCell(
            value: lines[i].designation,
            decoration: InputDecoration(
              labelText: s.fieldDesignation,
              isDense: true,
            ),
            onChanged: (v) => onChanged(i, lines[i].copyWith(designation: v)),
          ),
          const SizedBox(height: 8),
          _QtyCell(
            value: lines[i].quantite,
            decoration: InputDecoration(labelText: s.quantity, isDense: true),
            onChanged: (q) => onChanged(i, lines[i].copyWith(quantite: q)),
          ),
          if (editablePrice) ...[
            const SizedBox(height: 8),
            _QtyCell(
              value: lines[i].prixUnitaireHt,
              decoration: InputDecoration(labelText: s.colPuHt, isDense: true),
              onChanged: (p) => onChanged(
                i,
                lines[i].copyWith(prixUnitaireHt: p),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              if (available != null) _dispoText(lines[i], label: s.available),
              Text('${s.colRef} : ${lines[i].reference}'),
              if (!editablePrice)
                Text('${s.colPuHt} : ${formatMoney(lines[i].prixUnitaireHt)}'),
              Text(
                'TTC : ${formatMoney(lines[i].montantTtc)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final s = context.s;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.brandSoft),
          columns: [
            if (_showImages) DataColumn(label: Text(s.fieldPhoto)),
            DataColumn(label: Text(s.colRef)),
            DataColumn(label: Text(s.fieldDesignation)),
            DataColumn(label: Text(s.colQty), numeric: true),
            if (available != null)
              DataColumn(label: Text(s.colDispo), numeric: true),
            DataColumn(label: Text(s.colPuHt), numeric: true),
            DataColumn(label: Text(s.colRemise), numeric: true),
            DataColumn(label: Text(s.colTva), numeric: true),
            DataColumn(label: Text(s.colMontantHt), numeric: true),
            DataColumn(label: Text(s.colMontantTtc), numeric: true),
            const DataColumn(label: SizedBox.shrink()),
          ],
          rows: [
            for (var i = 0; i < lines.length; i++)
              DataRow(
                cells: [
                  if (_showImages) DataCell(_imageCell(lines[i])),
                  DataCell(Text(lines[i].reference)),
                  DataCell(
                    SizedBox(
                      width: 200,
                      child: _TextCell(
                        key: ValueKey('des-${lines[i].key}'),
                        value: lines[i].designation,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                        ),
                        onChanged: (v) =>
                            onChanged(i, lines[i].copyWith(designation: v)),
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 80,
                      child: _QtyCell(
                        key: ValueKey('qty-${lines[i].key}'),
                        value: lines[i].quantite,
                        decoration: const InputDecoration(isDense: true),
                        onChanged: (q) =>
                            onChanged(i, lines[i].copyWith(quantite: q)),
                      ),
                    ),
                  ),
                  if (available != null) DataCell(_dispoText(lines[i])),
                  DataCell(
                    editablePrice
                        ? SizedBox(
                            width: 100,
                            child: _QtyCell(
                              key: ValueKey('pu-${lines[i].key}'),
                              value: lines[i].prixUnitaireHt,
                              decoration: const InputDecoration(isDense: true),
                              onChanged: (p) => onChanged(
                                i,
                                lines[i].copyWith(prixUnitaireHt: p),
                              ),
                            ),
                          )
                        : Text(formatMoney(lines[i].prixUnitaireHt)),
                  ),
                  DataCell(Text(formatQty(lines[i].remise))),
                  DataCell(Text(formatQty(lines[i].tauxTva))),
                  DataCell(Text(formatMoney(lines[i].montantHt))),
                  DataCell(Text(formatMoney(lines[i].montantTtc))),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => onRemoveAt(i),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Text field that owns its controller so typing never loses focus, and only
/// takes the external [value] when it differs from what the user typed.
class _TextCell extends StatefulWidget {
  const _TextCell({
    super.key,
    required this.value,
    required this.onChanged,
    required this.decoration,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final InputDecoration decoration;

  @override
  State<_TextCell> createState() => _TextCellState();
}

class _TextCellState extends State<_TextCell> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _TextCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: widget.decoration,
      onChanged: widget.onChanged,
    );
  }
}

class _QtyCell extends StatefulWidget {
  const _QtyCell({
    super.key,
    required this.value,
    required this.onChanged,
    required this.decoration,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final InputDecoration decoration;

  @override
  State<_QtyCell> createState() => _QtyCellState();
}

class _QtyCellState extends State<_QtyCell> {
  late final TextEditingController _controller =
      TextEditingController(text: _format(widget.value));

  static String _format(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void didUpdateWidget(covariant _QtyCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (parseQty(_controller.text) != widget.value) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textAlign: TextAlign.end,
      decoration: widget.decoration,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      onChanged: (v) => widget.onChanged(parseQty(v)),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fes_distribution/ui/personnel/widgets/personnel_document_edit_page.dart';

class BonDechargeEditPage extends StatelessWidget {
  const BonDechargeEditPage({super.key, this.bonId});

  final int? bonId;

  @override
  Widget build(BuildContext context) =>
      PersonnelDocumentEditPage(kind: PersonnelDocKind.decharge, bonId: bonId);
}

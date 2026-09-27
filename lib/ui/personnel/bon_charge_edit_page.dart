import 'package:flutter/material.dart';
import 'package:fes_distribution/ui/personnel/widgets/personnel_document_edit_page.dart';

class BonChargeEditPage extends StatelessWidget {
  const BonChargeEditPage({super.key, this.bonId});

  final int? bonId;

  @override
  Widget build(BuildContext context) =>
      PersonnelDocumentEditPage(kind: PersonnelDocKind.charge, bonId: bonId);
}

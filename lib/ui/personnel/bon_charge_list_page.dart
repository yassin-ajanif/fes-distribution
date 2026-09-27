import 'package:flutter/material.dart';
import 'package:fes_distribution/ui/personnel/widgets/personnel_document_edit_page.dart';
import 'package:fes_distribution/ui/personnel/widgets/personnel_document_list_page.dart';

class BonChargeListPage extends StatelessWidget {
  const BonChargeListPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const PersonnelDocumentListPage(kind: PersonnelDocKind.charge);
}

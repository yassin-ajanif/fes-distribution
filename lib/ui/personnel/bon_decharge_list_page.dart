import 'package:flutter/material.dart';
import 'package:fes_distribution/ui/personnel/widgets/personnel_document_edit_page.dart';
import 'package:fes_distribution/ui/personnel/widgets/personnel_document_list_page.dart';

class BonDechargeListPage extends StatelessWidget {
  const BonDechargeListPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const PersonnelDocumentListPage(kind: PersonnelDocKind.decharge);
}

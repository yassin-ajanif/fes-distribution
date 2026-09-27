import 'package:fes_distribution/ui/l10n/app_language.dart';

class AppStrings {
  AppStrings(this.language);

  final AppLanguage language;

  String _t(String fr, String ar) =>
      language == AppLanguage.arabic ? ar : fr;

  // App shell
  String get appTitle => _t('Fes Distribution', 'Fes Distribution');
  String get menuTooltip => _t('Menu', 'القائمة');

  // Menu sections
  String get sectionDistribution => _t('Distribution', 'التوزيع');
  String get sectionVentes => _t('Ventes', 'المبيعات');
  String get sectionAchats => _t('Achats', 'المشتريات');
  String get sectionStockAdmin =>
      _t('Stock & administration', 'المخزون والإدارة');

  // Menu items
  String get menuVendeurs => _t('Vendeurs', 'البائعون');
  String get menuBonCharge => _t('Bons de charge', 'أذون الشحن');
  String get menuBonDecharge => _t('Bons de décharge', 'أذون التفريغ');
  String get menuBl => _t('Bons de livraison', 'أذون التسليم');
  String get menuFactures => _t('Factures', 'الفواتير');
  String get menuAvoirs => _t('Avoirs', 'الإشعارات الدائنة');
  String get menuBr => _t('Bons réception', 'أذون الاستلام');
  String get menuFacturesFournisseur =>
      _t('Factures fournisseur', 'فواتير الشراء');
  String get menuAvoirsFournisseur =>
      _t('Avoirs fournisseur', 'إشعارات دائنة للمورد');
  String get menuStock => _t('Stock', 'المخزون');
  String get menuProduits => _t('Produits', 'المنتجات');
  String get menuRapports => _t('Rapports', 'التقارير');
  String get menuParametres => _t('Paramètres', 'الإعدادات');

  // Common
  String get actionNew => _t('Nouveau', 'جديد');
  String get actionConfirm => _t('Confirmer', 'تأكيد');
  String get actionCancel => _t('Annuler', 'إلغاء');
  String get actionOk => _t('OK', 'موافق');
  String get actionContinue => _t('Continuer', 'متابعة');
  String get actionSave => _t('Enregistrer', 'حفظ');
  String get loading => _t('Chargement…', 'جاري التحميل…');
  String comingSoon(String module) =>
      _t('$module — bientôt disponible', '$module — قريباً');

  // Settings
  String get settingsTitle => _t('Paramètres', 'الإعدادات');
  String get settingsUiLanguage =>
      _t('Langue de l\'interface', 'لغة الواجهة');
  String get settingsLanguageHint => _t(
        'Choisissez la langue affichée dans l\'application.',
        'اختر اللغة المعروضة في التطبيق.',
      );
  String get settingsComingSoon => _t(
        'Paramètres société, TVA, sauvegarde…\n'
        'Le module paramètres sera connecté prochainement.',
        'إعدادات الشركة، الضريبة، النسخ الاحتياطي…\n'
        'سيتم ربط وحدة الإعدادات قريباً.',
      );
  String get settingsSaved => _t('Langue enregistrée.', 'تم حفظ اللغة.');

  // Placeholder modules — ventes
  String get searchBl =>
      _t('Rechercher numéro, client, vendeur…', 'بحث برقم، عميل، بائع…');
  String get emptyBl =>
      _t('Aucun bon de livraison.', 'لا يوجد أذن تسليم.');

  // Ventes — bons de livraison
  String get blNew => _t('Nouveau bon de livraison', 'أذن تسليم جديد');
  String get blSaved =>
      _t('Bon de livraison enregistré.', 'تم حفظ أذن التسليم.');
  String get blFlow => _t(
        'Véhicule du vendeur → client',
        'سيارة البائع ← العميل',
      );
  String get fieldClient => _t('Client', 'العميل');
  String get newClient => _t('Nouveau client', 'عميل جديد');
  String get fieldTelephone => _t('Téléphone', 'الهاتف');
  String get fieldVille => _t('Ville', 'المدينة');
  String get fieldDateEcheance => _t('Échéance', 'تاريخ الاستحقاق');
  String get fieldRemiseGlobale => _t('Remise globale (%)', 'خصم إجمالي (%)');
  String get errSelectClient => _t('Sélectionnez un client.', 'اختر عميلاً.');
  String get errRemiseGlobale => _t(
        'La remise globale doit être entre 0 et 100 %.',
        'يجب أن يكون الخصم الإجمالي بين 0 و 100 %.',
      );
  String get noClient => _t(
        'Aucun client. Ajoutez-en un avec le bouton +.',
        'لا يوجد عميل. أضف عميلاً بالزر +.',
      );
  String get colTotalTtc => _t('Total TTC', 'المجموع مع الضريبة');
  String get colStatut => _t('Statut', 'الحالة');
  String get colReste => _t('Reste', 'الباقي');
  String get statusPaye => _t('Payé', 'مدفوع');
  String get statusNonPaye => _t('Non payé', 'غير مدفوع');
  String montantPaye(String v) => _t('Payé : $v', 'المدفوع: $v');
  String resteAPayer(String v) => _t('Reste à payer : $v', 'الباقي للدفع: $v');

  // Paiements
  String get paiements => _t('Paiements', 'الدفعات');
  String get addPaiement => _t('Ajouter un paiement', 'إضافة دفعة');
  String get noPaiement =>
      _t('Aucun paiement enregistré.', 'لا توجد دفعات مسجلة.');
  String get fieldMontant => _t('Montant', 'المبلغ');
  String get fieldMode => _t('Mode', 'طريقة الدفع');
  String get fieldReference2 => _t('Référence (chèque, virement…)', 'المرجع (شيك، تحويل…)');
  String get errAmount => _t(
        'Le montant doit être supérieur à 0.',
        'يجب أن يكون المبلغ أكبر من 0.',
      );
  String errPaymentsExceed(String paid, String ttc) => _t(
        'La somme des paiements ($paid) ne peut pas dépasser le total TTC ($ttc).',
        'مجموع الدفعات ($paid) لا يمكن أن يتجاوز المجموع مع الضريبة ($ttc).',
      );
  String get modeCredit => _t('Crédit', 'آجل');
  String get modeCheque => _t('Chèque', 'شيك');
  String get modeEspeces => _t('Espèces', 'نقداً');
  String get modeTpe => _t('TPE', 'بطاقة');
  String get modeVirement => _t('Virement', 'تحويل');
  String get modeEffet => _t('Effet', 'كمبيالة');
  String get searchFacture =>
      _t('Rechercher numéro, client…', 'بحث برقم، عميل…');
  String get emptyFacture => _t('Aucune facture.', 'لا توجد فاتورة.');

  // Ventes — factures
  String get factureNew => _t('Nouvelle facture', 'فاتورة جديدة');
  String get factureSaved => _t('Facture enregistrée.', 'تم حفظ الفاتورة.');
  String get fieldEstPayee => _t('Facture payée', 'فاتورة مدفوعة');
  String get fieldBonCommandeRef =>
      _t('Réf. bon de commande client', 'مرجع طلبية العميل');
  String get linkedBls => _t('Bons de livraison facturés', 'أذون التسليم المفوترة');
  String get addBls => _t('Ajouter des BL', 'إضافة أذون تسليم');
  String get noLinkedBl => _t(
        'Aucun BL lié. Ajoutez des BL ou des produits du catalogue.',
        'لا يوجد أذن تسليم مرتبط. أضف أذون تسليم أو منتجات.',
      );
  String get noAvailableBls => _t(
        'Aucun BL non facturé pour ce client.',
        'لا يوجد أذن تسليم غير مفوتر لهذا العميل.',
      );
  String get clientLockedByBl => _t(
        'Retirez les BL liés pour changer de client.',
        'احذف أذون التسليم المرتبطة لتغيير العميل.',
      );
  String get colEcheance => _t('Échéance', 'الاستحقاق');
  String get colBls => _t('BL', 'أذون التسليم');
  String get statusEnRetard => _t('En retard', 'متأخرة');
  String get filterAll => _t('Toutes', 'الكل');
  String blInvoiced(String numero) =>
      _t('Facturé sur $numero', 'مفوتر في $numero');
  String get actionInvoice => _t('Facturer', 'فوترة');
  String get searchAvoir =>
      _t('Rechercher numéro, client…', 'بحث برقم، عميل…');
  String get emptyAvoir => _t(
        'Aucun avoir.\nLe module ventes sera connecté prochainement.',
        'لا يوجد إشعار دائن.\nسيتم ربط وحدة المبيعات قريباً.',
      );

  // Achats — common
  String get fieldFournisseur => _t('Fournisseur', 'المورد');
  String get newFournisseur => _t('Nouveau fournisseur', 'مورد جديد');
  String get errSelectFournisseur =>
      _t('Sélectionnez un fournisseur.', 'اختر مورداً.');
  String get noFournisseur => _t(
        'Aucun fournisseur. Ajoutez-en un avec le bouton +.',
        'لا يوجد مورد. أضف مورداً بالزر +.',
      );
  String get colFacture => _t('Facture', 'الفاتورة');

  // Achats — bons de réception
  String get searchBr =>
      _t('Rechercher numéro, fournisseur…', 'بحث برقم، مورد…');
  String get emptyBr => _t('Aucun bon de réception.', 'لا يوجد أذن استلام.');
  String get brNew => _t('Nouveau bon de réception', 'أذن استلام جديد');
  String get brSaved =>
      _t('Bon de réception enregistré.', 'تم حفظ أذن الاستلام.');
  String brFlow(String depot) =>
      _t('Fournisseur → $depot', 'المورد ← $depot');

  // Achats — factures fournisseur
  String get searchFactureFournisseur =>
      _t('Rechercher numéro, fournisseur…', 'بحث برقم، مورد…');
  String get emptyFactureFournisseur =>
      _t('Aucune facture fournisseur.', 'لا توجد فاتورة مورد.');
  String get factureFournisseurNew =>
      _t('Nouvelle facture fournisseur', 'فاتورة مورد جديدة');
  String get factureFournisseurSaved =>
      _t('Facture fournisseur enregistrée.', 'تم حفظ فاتورة المورد.');
  String get linkedBrs =>
      _t('Bons de réception facturés', 'أذون الاستلام المفوترة');
  String get addBrs => _t('Ajouter des BR', 'إضافة أذون استلام');
  String get noLinkedBr => _t(
        'Aucun BR lié. Ajoutez des BR ou des produits du catalogue.',
        'لا يوجد أذن استلام مرتبط. أضف أذون استلام أو منتجات.',
      );
  String get noAvailableBrs => _t(
        'Aucun BR non facturé pour ce fournisseur.',
        'لا يوجد أذن استلام غير مفوتر لهذا المورد.',
      );
  String get fournisseurLockedByBr => _t(
        'Retirez les BR liés pour changer de fournisseur.',
        'احذف أذون الاستلام المرتبطة لتغيير المورد.',
      );
  String get colBrs => _t('BR', 'أذون الاستلام');

  // Achats — avoirs fournisseur
  String get searchAvoirFournisseur =>
      _t('Rechercher numéro, fournisseur, motif…', 'بحث برقم، مورد، سبب…');
  String get emptyAvoirFournisseur =>
      _t('Aucun avoir fournisseur.', 'لا يوجد إشعار دائن للمورد.');
  String get avoirFournisseurNew =>
      _t('Nouvel avoir fournisseur', 'إشعار دائن جديد للمورد');
  String get avoirFournisseurSaved =>
      _t('Avoir fournisseur enregistré.', 'تم حفظ الإشعار الدائن للمورد.');
  String get fieldMotif => _t('Motif', 'السبب');
  String get fieldRetourMarchandise =>
      _t('Retour de marchandise', 'إرجاع البضاعة');
  String retourMarchandiseHint(String depot) => _t(
        'Les quantités sortent du stock « $depot ».',
        'تخرج الكميات من مخزون « $depot ».',
      );
  String get noRetourMarchandiseHint => _t(
        'Avoir sur prix uniquement : aucun mouvement de stock.',
        'إشعار على السعر فقط: لا توجد حركة مخزون.',
      );

  // Placeholder modules — stock & admin
  String get searchStock =>
      _t('Rechercher référence, désignation…', 'بحث بالمرجع، التسمية…');
  String get emptyStock => _t(
        'Aucun produit actif.\nAjoutez des produits dans « Produits ».',
        'لا يوجد منتج نشط.\nأضف منتجات من « المنتجات ».',
      );
  String get searchProduits =>
      _t('Rechercher référence, code-barres…', 'بحث بالمرجع، الرمز…');
  String get emptyProduits => _t(
        'Aucun produit.\nAppuyez sur « Nouveau » pour en ajouter.',
        'لا يوجد منتج.\nاضغط على « جديد » لإضافة منتج.',
      );

  // Produits
  String get produitNew => _t('Nouveau produit', 'منتج جديد');
  String get produitSaved => _t('Produit enregistré.', 'تم حفظ المنتج.');
  String get sectionIdentification => _t('Identification', 'التعريف');
  String get sectionPrix => _t('Prix & TVA', 'الأسعار والضريبة');
  String get fieldReference => _t('Référence', 'المرجع');
  String get fieldDesignation => _t('Désignation', 'التسمية');
  String get fieldCodeBarre => _t('Code-barres', 'الرمز الشريطي');
  String get fieldUnite => _t('Unité', 'الوحدة');
  String get fieldPrixAchat => _t('Prix d\'achat HT', 'سعر الشراء بدون ضريبة');
  String get fieldPrixVente => _t('Prix de vente HT', 'سعر البيع بدون ضريبة');
  String get fieldTva => _t('TVA (%)', 'الضريبة (%)');
  String get fieldStockMin => _t('Stock minimum', 'الحد الأدنى للمخزون');
  String get fieldCategorie => _t('Catégorie', 'الفئة');
  String get fieldActif => _t('Actif', 'نشط');
  String get fieldName => _t('Nom', 'الاسم');
  String get noCategorie => _t('Aucune', 'بدون');
  String get newCategorie => _t('Nouvelle catégorie', 'فئة جديدة');
  String get inactive => _t('Inactif', 'غير نشط');
  String get requiredField => _t('Champ obligatoire', 'حقل إلزامي');
  String get invalidNumber => _t('Nombre invalide', 'رقم غير صالح');
  String get stockDepots => _t('Stock dépôts', 'مخزون المستودعات');

  // Stock
  String get stockLocation => _t('Emplacement', 'الموقع');
  String get locationPhysical => _t('Dépôt', 'مستودع');
  String get locationVirtual => _t('Vendeur', 'بائع');
  String get newDepot => _t('Nouveau dépôt', 'مستودع جديد');
  String get depotCreated => _t('Dépôt créé.', 'تم إنشاء المستودع.');
  String get adjustStock => _t('Ajuster le stock', 'تعديل المخزون');
  String get adjustDelta =>
      _t('Variation (+ ajoute, − retire)', 'التغيير (+ إضافة، − سحب)');
  String get adjustMotif => _t('Motif', 'السبب');
  String get adjustDone => _t('Stock ajusté.', 'تم تعديل المخزون.');
  String get currentStock => _t('Stock actuel', 'المخزون الحالي');
  String get stockToAdd => _t(
        'Quantité à ajouter (− pour retirer)',
        'الكمية المضافة (− للسحب)',
      );
  String stockBeforeAfter(String before, String after) =>
      _t('Stock : $before → $after', 'المخزون: $before ← $after');
  String get stockNegative => _t(
        'Le stock ne peut pas devenir négatif.',
        'لا يمكن أن يصبح المخزون سالبًا.',
      );
  String get produitStockMotif => _t('Fiche produit', 'بطاقة المنتج');
  String get transfer => _t('Transfert', 'تحويل');
  String get transferTitle =>
      _t('Transfert entre dépôts', 'تحويل بين المستودعات');
  String get fromDepot => _t('Dépôt source', 'المستودع المصدر');
  String get toDepot => _t('Dépôt destination', 'المستودع الوجهة');
  String get addProduct => _t('Ajouter un produit', 'إضافة منتج');
  String get searchProduct =>
      _t('Rechercher un produit…', 'بحث عن منتج…');
  String get noLines => _t(
        'Aucune ligne — ajoutez un produit ci-dessus.',
        'لا توجد أسطر — أضف منتجاً أعلاه.',
      );
  String get quantity => _t('Quantité', 'الكمية');
  String get note => _t('Note', 'ملاحظة');
  String available(String qty) => _t('Dispo : $qty', 'المتوفر: $qty');
  String get transferDone =>
      _t('Transfert enregistré.', 'تم تسجيل التحويل.');
  String get needTwoDepots => _t(
        'Créez au moins deux dépôts (page Stock → Nouveau dépôt) pour faire un transfert.',
        'أنشئ مستودعين على الأقل (صفحة المخزون ← مستودع جديد) لإجراء تحويل.',
      );
  String shortageLine(String ref, String requested, String available) => _t(
        '$ref — demandé $requested, dispo $available',
        '$ref — مطلوب $requested، متوفر $available',
      );
  String get searchRapports =>
      _t('Rechercher un rapport…', 'بحث عن تقرير…');
  String get emptyRapports => _t(
        'Aucun rapport disponible.\nLe module rapports sera connecté prochainement.',
        'لا يوجد تقرير.\nسيتم ربط وحدة التقارير قريباً.',
      );

  // Distribution — vendeurs
  String get searchVendeur =>
      _t('Rechercher un vendeur…', 'بحث عن بائع…');
  String get emptyVendeurs =>
      _t('Aucun vendeur trouvé.', 'لم يُعثر على بائع.');

  // Distribution — bons charge / décharge
  String get searchBon => _t('Rechercher numéro, vendeur…', 'بحث برقم، بائع…');
  String get emptyBonCharge =>
      _t('Aucun bon de charge.', 'لا يوجد أذن شحن.');
  String get emptyBonDecharge =>
      _t('Aucun bon de décharge.', 'لا يوجد أذن تفريغ.');
  String deleteBonConfirm(String numero) => _t(
        'Supprimer $numero ?',
        'حذف $numero ؟',
      );
  String get bonChargeNew => _t('Nouveau bon de charge', 'أذن شحن جديد');
  String get bonDechargeNew => _t('Nouveau bon de décharge', 'أذن تفريغ جديد');
  String get bonChargeSaved =>
      _t('Bon de charge enregistré.', 'تم حفظ أذن الشحن.');
  String get bonDechargeSaved =>
      _t('Bon de décharge enregistré.', 'تم حفظ أذن التفريغ.');
  String get bonChargeFlow => _t(
        'Dépôt → véhicule du vendeur',
        'المستودع ← سيارة البائع',
      );
  String get bonDechargeFlow => _t(
        'Véhicule du vendeur → dépôt',
        'سيارة البائع ← المستودع',
      );
  String get fieldVendeur => _t('Vendeur', 'البائع');
  String get fieldDepot => _t('Dépôt', 'المستودع');
  String get fieldDate => _t('Date', 'التاريخ');
  String get colNumero => _t('Numéro', 'الرقم');
  String get colRef => _t('Réf.', 'المرجع');
  String get colQty => _t('Qté', 'الكمية');
  String get colPuHt => _t('PU HT', 'س.و بدون ض');
  String get colRemise => _t('Rem.%', 'خصم%');
  String get colTva => _t('TVA%', 'ض.ق.م%');
  String get colMontantHt => _t('Montant HT', 'المبلغ بدون ضريبة');
  String get colMontantTtc => _t('Montant TTC', 'المبلغ مع الضريبة');
  String get colDispo => _t('Dispo', 'المتوفر');
  String totalHt(String v) => _t('Total HT : $v', 'المجموع بدون ضريبة: $v');
  String totalTva(String v) => _t('Total TVA : $v', 'مجموع الضريبة: $v');
  String totalTtc(String v) => _t('Total TTC : $v', 'المجموع مع الضريبة: $v');
  String get actionOpen => _t('Ouvrir', 'فتح');
  String get actionDelete => _t('Supprimer', 'حذف');
  String get filterDate => _t('Filtrer par date', 'تصفية حسب التاريخ');
  String get clearFilter => _t('Effacer le filtre', 'مسح التصفية');
  String get errSelectVendeur =>
      _t('Sélectionnez un vendeur.', 'اختر بائعاً.');
  String get errSelectDepot => _t('Sélectionnez un dépôt.', 'اختر مستودعاً.');
  String get errNoLines => _t(
        'Ajoutez au moins une ligne avec quantité.',
        'أضف سطراً واحداً على الأقل بكمية.',
      );
  String get errZeroTtc => _t(
        'Le total TTC ne peut pas être nul.',
        'لا يمكن أن يكون المجموع مع الضريبة صفراً.',
      );
  String get noActiveVendeur => _t(
        'Aucun vendeur actif. Ajoutez un vendeur dans « Vendeurs ».',
        'لا يوجد بائع نشط. أضف بائعاً من « البائعون ».',
      );
  String get unloadAll =>
      _t('Décharger tout le véhicule', 'تفريغ كل السيارة');
  String get unloadAllEmpty => _t(
        'Le véhicule de ce vendeur est vide.',
        'سيارة هذا البائع فارغة.',
      );
  String get unloadAllReplace => _t(
        'Remplacer les lignes actuelles par tout le stock du véhicule ?',
        'استبدال الأسطر الحالية بكل مخزون السيارة؟',
      );

  // Stock shortage dialog
  String get stockShortageTitle =>
      _t('Stock insuffisant', 'مخزون غير كافٍ');
  String stockShortageMessage(List<String> lines) => _t(
        'Certains produits n\'ont pas assez de stock disponible :\n\n${lines.join('\n')}\n\nContinuer quand même ?',
        'بعض المنتجات لا تتوفر بكمية كافية:\n\n${lines.join('\n')}\n\nالمتابعة على أي حال؟',
      );
}

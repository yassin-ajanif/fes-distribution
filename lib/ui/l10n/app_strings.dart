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
  String get emptyBl => _t(
        'Aucun bon de livraison.\nLe module ventes sera connecté prochainement.',
        'لا يوجد أذن تسليم.\nسيتم ربط وحدة المبيعات قريباً.',
      );
  String get searchFacture =>
      _t('Rechercher numéro, client…', 'بحث برقم، عميل…');
  String get emptyFacture => _t(
        'Aucune facture.\nLe module ventes sera connecté prochainement.',
        'لا توجد فاتورة.\nسيتم ربط وحدة المبيعات قريباً.',
      );
  String get searchAvoir =>
      _t('Rechercher numéro, client…', 'بحث برقم، عميل…');
  String get emptyAvoir => _t(
        'Aucun avoir.\nLe module ventes sera connecté prochainement.',
        'لا يوجد إشعار دائن.\nسيتم ربط وحدة المبيعات قريباً.',
      );

  // Placeholder modules — achats
  String get searchBr =>
      _t('Rechercher numéro, fournisseur…', 'بحث برقم، مورد…');
  String get emptyBr => _t(
        'Aucun bon réception.\nLe module achats sera connecté prochainement.',
        'لا يوجد أذن استلام.\nسيتم ربط وحدة المشتريات قريباً.',
      );
  String get searchFactureFournisseur =>
      _t('Rechercher numéro, fournisseur…', 'بحث برقم، مورد…');
  String get emptyFactureFournisseur => _t(
        'Aucune facture fournisseur.\nLe module achats sera connecté prochainement.',
        'لا توجد فاتورة مورد.\nسيتم ربط وحدة المشتريات قريباً.',
      );
  String get searchAvoirFournisseur =>
      _t('Rechercher numéro, fournisseur…', 'بحث برقم، مورد…');
  String get emptyAvoirFournisseur => _t(
        'Aucun avoir fournisseur.\nLe module achats sera connecté prochainement.',
        'لا يوجد إشعار دائن للمورد.\nسيتم ربط وحدة المشتريات قريباً.',
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

  // Stock shortage dialog
  String get stockShortageTitle =>
      _t('Stock insuffisant', 'مخزون غير كافٍ');
  String stockShortageMessage(List<String> lines) => _t(
        'Certains produits n\'ont pas assez de stock disponible :\n\n${lines.join('\n')}\n\nContinuer quand même ?',
        'بعض المنتجات لا تتوفر بكمية كافية:\n\n${lines.join('\n')}\n\nالمتابعة على أي حال؟',
      );
}

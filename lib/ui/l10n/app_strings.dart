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
        'Aucun produit en stock.\nLe module stock sera connecté prochainement.',
        'لا يوجد منتج في المخزون.\nسيتم ربط وحدة المخزون قريباً.',
      );
  String get searchProduits =>
      _t('Rechercher référence, code-barres…', 'بحث بالمرجع، الرمز…');
  String get emptyProduits => _t(
        'Aucun produit.\nLe catalogue produits sera connecté prochainement.',
        'لا يوجد منتج.\nسيتم ربط فهرس المنتجات قريباً.',
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

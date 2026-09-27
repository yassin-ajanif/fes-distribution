# Flutter Setup & Roadmap — FesDistribution

Guide for bootstrapping this project. Use **TangerAppAndroid** as the Flutter setup reference and **Peinture distribution** as the business-logic reference.

## Reference projects

| Project | Path | Use for |
|---------|------|---------|
| **TangerAppAndroid** | `C:\Users\yassin\Desktop\TangerAppAndroid` | Flutter project setup, Drift config, bootstrap pattern, dependencies |
| **Peinture distribution** | `C:\Users\yassin\Desktop\Peinture distribution` | Business rules, workflows, screens behavior |
| **FesDistribution docs** | `docs/architecture.md`, `docs/database-design.md` | Folder structure and DB schema |

---

## Prerequisites

- Flutter SDK (TangerAppAndroid uses `%USERPROFILE%\develop\flutter`)
- Windows desktop target enabled
- Dart SDK compatible with Flutter (Tanger uses `^3.13.3`)

Verify:

```powershell
flutter doctor
flutter config --enable-windows-desktop
```

---

## Create the project

From `C:\Users\yassin\Desktop\FesDistribution`:

```powershell
flutter create . --org com.fesdistribution --project-name fes_distribution --platforms=windows
```

Then replace the default `lib/` layout with the structure in `docs/architecture.md`:

```text
lib/
├── main.dart
├── ui/
├── business/
└── db/
```

---

## Dependencies

Based on **TangerAppAndroid** `pubspec.yaml`, adapted for this project.

### `pubspec.yaml` template

```yaml
name: fes_distribution
description: "Flutter clone of Peinture distribution (DistributionPeinture)"
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.13.3

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  cupertino_icons: ^1.0.8

  # Database (from TangerAppAndroid)
  drift: ^2.28.1
  drift_flutter: ^0.2.4
  sqlite3_flutter_libs: ^0.5.34
  path_provider: ^2.1.5
  path: ^1.9.1

  # State & routing (FesDistribution architecture)
  flutter_riverpod: ^2.6.1
  go_router: ^16.0.0

  # Utils (from TangerAppAndroid)
  intl: ^0.20.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  drift_dev: ^2.28.1
  build_runner: ^2.4.15

flutter:
  uses-material-design: true
  assets:
    - assets/l10n/
```

Install:

```powershell
flutter pub get
```

### TangerAppAndroid vs FesDistribution

| Package | TangerAppAndroid | FesDistribution |
|---------|------------------|-----------------|
| Drift | yes | yes |
| drift_flutter | yes | yes |
| sqlite3_flutter_libs | yes | yes |
| path_provider | yes | yes |
| provider | yes | **no** — use `flutter_riverpod` |
| go_router | no | yes |
| intl | yes | yes |

---

## Drift setup (copy pattern from TangerAppAndroid)

Tanger reference: `TangerAppAndroid/lib/data/app_database.dart`

### Connection

Use `drift_flutter` with a named local DB file:

```dart
// db/connection.dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

QueryExecutor openConnection() {
  return driftDatabase(name: 'fes_distribution');
}
```

Peinture distribution stores data at `%AppData%\DistributionPeinture\data.db`. For desktop parity, you can later switch to an explicit path via `path_provider` + `NativeDatabase.createInBackground`.

### AppDatabase skeleton

```dart
// db/app_database.dart
import 'package:drift/drift.dart';
import 'connection.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [/* add tables from docs/database-design.md */])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // seed AppSettings, default StockLocation, etc.
    },
    onUpgrade: (m, from, to) async {
      // see db/migrations/
    },
  );
}
```

### Code generation

When Drift tables change (same as TangerAppAndroid README):

```powershell
dart run build_runner build --delete-conflicting-outputs
```

Watch mode during development:

```powershell
dart run build_runner watch --delete-conflicting-outputs
```

---

## App bootstrap (adapt from TangerAppAndroid)

Tanger reference: `TangerAppAndroid/lib/main.dart`

Pattern:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. Open `AppDatabase`
3. Create services (inject `AppDatabase`)
4. Bootstrap settings / seed data
5. Run app with Riverpod + `MaterialApp.router`

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();
  // create services, pass database
  // await bootstrap settings

  runApp(
    ProviderScope(
      child: FesDistributionApp(database: database),
    ),
  );
}
```

Tanger uses `Provider` + `MultiProvider`. This project uses **Riverpod** per `docs/architecture.md`, but the bootstrap sequence is the same.

---

## Run & test

From TangerAppAndroid README:

```powershell
flutter run
flutter run -d windows
flutter test
flutter analyze
```

---

## Recommended analysis options

Copy from TangerAppAndroid `analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - build/**
    - android/**
    - web/**
    - windows/**

linter:
  rules:
    # project-specific rules as needed
```

---

## Localization (optional, from Tanger)

TangerAppAndroid stores French/Arabic strings in `assets/l10n/` with RTL support.

For FesDistribution, follow the same pattern if bilingual UI is needed:

```text
assets/l10n/
  fr.json
  ar.json
```

Peinture distribution uses `UiLanguage` in `AppSettings` — wire localization to that setting.

---

## Implementation roadmap

### Phase 0 — Project skeleton

- [ ] `flutter create` with Windows target
- [ ] Add dependencies from this doc
- [ ] Create `lib/ui/`, `lib/business/`, `lib/db/` folders
- [ ] Setup `AppDatabase` + `connection.dart`
- [ ] Setup Riverpod + go_router app shell
- [ ] Copy theme approach from Tanger (`ui/theme/app_theme.dart`)

### Phase 1 — Foundation

Modules: auth, tiers, stock, settings

- [ ] Drift tables: `Users`, `Tiers`, `Categories`, `Produits`, `StockLocations`, `MouvementsStock`, `AppSettings`
- [ ] Seed: default depot (`Dépôt principal`), default settings row
- [ ] Services: `user_service`, `tiers_service`, `produit_service`, `stock_location_service`, `stock_balance_service`, `stock_movement_service`, `settings_service`
- [ ] UI: app shell, tiers list/detail, produits, stock movements, settings
- [ ] Reference Peinture: `Modules/Tiers`, `Modules/Stock`, `Modules/Auth`

### Phase 2 — Sales core

Modules: devis, commande_client, livraison

- [ ] Tables: `Devis`, `BonsCommandeClient`, `BonsLivraison`, payments
- [ ] Services: `devis_service`, `bon_commande_client_service`, `bon_livraison_service` (incl. validation, stock, payments)
- [ ] UI: list + edit pages for each document
- [ ] Reference Peinture: `Modules/Devis`, `Modules/CommandeClient`, `Modules/Livraison`

### Phase 3 — Client billing

Modules: facturation

- [ ] Tables: `Factures`, `Avoirs` + line tables
- [ ] Services: `facture_service`, `avoir_service`
- [ ] Reference Peinture: `Modules/Facturation`

### Phase 4 — Purchases

Modules: commande_fournisseur, reception, facture_fournisseur, avoir_fournisseur

- [ ] Tables: supplier documents + payments
- [ ] Services: `bon_reception_service`, `facture_fournisseur_service`, `avoir_fournisseur_service`
- [ ] Reference Peinture: `Modules/CommandeFournisseur`, `Modules/Reception`, `Modules/FactureFournisseur`, `Modules/AvoirFournisseur`

### Phase 5 — Personnel & charges

- [ ] Tables: `BonsCharge`, `BonsDecharge`, `RemisesCaisse`, `Charges`
- [ ] Services: `bon_charge_service`, `bon_decharge_service`, `remise_caisse_service`, `charge_service`
- [ ] Reference Peinture: `Modules/Personnel`, `Modules/Charges`

### Phase 6 — Reporting & polish

- [ ] PDF generation (`business/services/pdf_service.dart`)
- [ ] Document numbering (`document_number_service.dart`)
- [ ] Backup/export
- [ ] Reports
- [ ] Reference Peinture: `Shared/Services/PdfService.cs`, `Modules/Reporting`

---

## TangerAppAndroid files to study

| Tanger file | What to copy |
|-------------|--------------|
| `pubspec.yaml` | Drift dependency versions, dev_dependencies |
| `lib/data/app_database.dart` | Drift table + migration + connection pattern |
| `lib/main.dart` | Bootstrap sequence |
| `lib/state/app_state.dart` | App-level state pattern (adapt to Riverpod) |
| `lib/screens/app_shell.dart` | Shell navigation layout |
| `lib/theme.dart` | Theme/colors approach |
| `README.md` | Run/build_runner commands |
| `analysis_options.yaml` | Lint setup |

**Do not copy** Tanger's `StationRepository` pattern — FesDistribution uses services calling Drift directly (see `docs/architecture.md`).

---

## Related docs

- [Architecture](./architecture.md)
- [Database Design](./database-design.md)

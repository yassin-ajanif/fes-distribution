# Architecture — Distribution Peinture (Flutter)

Flutter desktop clone of **Peinture distribution** using a simple **3-layer** structure.

## Principles

- **3 main folders only:** `ui/`, `business/`, `db/`
- **No repository layer** — services call Drift directly
- **No global DTO layer** — use business models; add UI list/edit models only when a screen needs them
- **One service per entity/module** — all business logic of an entity (queries, save, validation, stock effects, payments) lives in one service class
- **Drift + SQLite** for local-first storage

## Data Flow

```text
ui/page
  ↓
business/service
  ↓
db/app_database + tables
```

Example:

```text
ui/livraison/bl_edit_page.dart
  → business/services/bon_livraison_service.dart   (save, validate, stock, payments)
    → business/services/stock_movement_service.dart (shared stock engine)
      → db/app_database.dart
```

---

## Folder Structure

```text
lib/
├── main.dart
│
├── ui/
│   ├── app/
│   │   ├── app.dart
│   │   ├── router.dart
│   │   └── shell_page.dart
│   ├── theme/
│   │   └── app_theme.dart
│   ├── common/
│   │   ├── app_button.dart
│   │   ├── app_text_field.dart
│   │   └── loading_view.dart
│   ├── auth/
│   │   ├── login_page.dart
│   │   └── vendeurs_page.dart
│   ├── tiers/
│   │   ├── tiers_list_page.dart
│   │   └── tiers_detail_page.dart
│   ├── stock/
│   │   ├── stock_page.dart
│   │   ├── produits_page.dart
│   │   └── mouvements_page.dart
│   ├── devis/
│   │   ├── devis_list_page.dart
│   │   └── devis_edit_page.dart
│   ├── commande_client/
│   │   ├── bc_client_list_page.dart
│   │   └── bc_client_edit_page.dart
│   ├── livraison/
│   │   ├── bl_list_page.dart
│   │   └── bl_edit_page.dart
│   ├── facturation/
│   │   ├── facture_list_page.dart
│   │   ├── facture_edit_page.dart
│   │   ├── avoir_list_page.dart
│   │   └── avoir_edit_page.dart
│   ├── commande_fournisseur/
│   │   ├── bc_fournisseur_list_page.dart
│   │   └── bc_fournisseur_edit_page.dart
│   ├── reception/
│   │   ├── br_list_page.dart
│   │   └── br_edit_page.dart
│   ├── facture_fournisseur/
│   │   ├── facture_fournisseur_list_page.dart
│   │   └── facture_fournisseur_edit_page.dart
│   ├── avoir_fournisseur/
│   │   ├── avoir_fournisseur_list_page.dart
│   │   └── avoir_fournisseur_edit_page.dart
│   ├── personnel/
│   │   ├── bon_charge_list_page.dart
│   │   ├── bon_charge_edit_page.dart
│   │   ├── bon_decharge_list_page.dart
│   │   ├── bon_decharge_edit_page.dart
│   │   └── remise_caisse_page.dart
│   ├── charges/
│   │   ├── charge_list_page.dart
│   │   └── charge_edit_page.dart
│   ├── reporting/
│   │   └── reports_page.dart
│   └── settings/
│       └── settings_page.dart
│
├── business/
│   ├── models/
│   │   ├── user.dart
│   │   ├── tier.dart
│   │   ├── produit.dart
│   │   ├── categorie.dart
│   │   ├── stock_location.dart
│   │   ├── mouvement_stock.dart
│   │   ├── devis.dart
│   │   ├── bon_commande_client.dart
│   │   ├── bon_livraison.dart
│   │   ├── facture.dart
│   │   ├── avoir.dart
│   │   ├── bon_commande.dart
│   │   ├── bon_reception.dart
│   │   ├── facture_fournisseur.dart
│   │   ├── avoir_fournisseur.dart
│   │   ├── charge.dart
│   │   ├── bon_charge.dart
│   │   ├── bon_decharge.dart
│   │   ├── remise_caisse.dart
│   │   └── app_settings.dart
│   ├── enums/
│   │   ├── mode_paiement.dart
│   │   ├── type_tiers.dart
│   │   └── user_type.dart
│   ├── services/                      # mirrors the sidebar: section → menu item
│   │   ├── distribution/              # sidebar: Distribution
│   │   │   ├── vendeurs/
│   │   │   │   ├── user_service.dart
│   │   │   │   └── vendeur_stock_service.dart
│   │   │   ├── bons_charge/
│   │   │   │   └── bon_charge_service.dart
│   │   │   └── bons_decharge/
│   │   │       └── bon_decharge_service.dart
│   │   ├── ventes/                    # sidebar: Ventes
│   │   │   ├── bons_livraison/bon_livraison_service.dart
│   │   │   ├── clients/tiers_service.dart     # clients picked on BL (quick-create from the BL form)
│   │   │   ├── factures/facture_service.dart
│   │   │   └── avoirs/avoir_service.dart
│   │   ├── achats/                    # sidebar: Achats
│   │   │   ├── bons_reception/bon_reception_service.dart
│   │   │   ├── factures_fournisseur/facture_fournisseur_service.dart
│   │   │   └── avoirs_fournisseur/avoir_fournisseur_service.dart
│   │   └── stock/                     # sidebar: Stock & administration
│   │       ├── stock/                 # menu item "Stock"
│   │       │   ├── stock_location_service.dart
│   │       │   ├── stock_balance_service.dart
│   │       │   └── stock_movement_service.dart
│   │       ├── produits/
│   │       │   ├── produit_service.dart
│   │       │   └── categorie_service.dart
│   │       ├── rapports/report_service.dart
│   │       └── parametres/
│   │           ├── app_settings_service.dart
│   │           └── document_number_service.dart
│   └── mappers/
│       ├── tier_mapper.dart
│       ├── produit_mapper.dart
│       ├── bon_livraison_mapper.dart
│       └── ...
│
└── db/
    ├── app_database.dart
    ├── app_database.g.dart
    ├── connection.dart
    ├── migrations/
    │   ├── migration_v1.dart
    │   └── migration_v2.dart
    └── entities/
        ├── users.dart
        ├── tiers.dart
        ├── categories.dart
        ├── produits.dart
        ├── stock_locations.dart
        ├── mouvements_stock.dart
        ├── devis.dart
        ├── devis_lignes.dart
        ├── bons_commande_client.dart
        ├── bon_commande_client_lignes.dart
        ├── bons_livraison.dart
        ├── bon_livraison_lignes.dart
        ├── paiements_bon_livraison.dart
        ├── factures.dart
        ├── facture_lignes.dart
        ├── avoirs.dart
        ├── avoir_lignes.dart
        ├── bons_commande.dart
        ├── bon_commande_lignes.dart
        ├── bons_reception.dart
        ├── bon_reception_lignes.dart
        ├── factures_fournisseurs.dart
        ├── facture_fournisseur_lignes.dart
        ├── paiements_fournisseurs.dart
        ├── avoirs_fournisseurs.dart
        ├── avoir_fournisseur_lignes.dart
        ├── types_charges.dart
        ├── charges.dart
        ├── bons_charge.dart
        ├── bon_charge_lignes.dart
        ├── bons_decharge.dart
        ├── bon_decharge_lignes.dart
        ├── remises_caisse.dart
        └── app_settings.dart
```

---

## Layer Responsibilities

### `ui/` — Presentation

Screens, widgets, routing, theme, and screen-level state.

**Contains:**
- pages
- reusable widgets
- app shell and navigation
- theme

**Does not contain:**
- business rules
- stock validation
- SQL / Drift code

### `business/` — Application logic

Models, services, enums, and mappers.

**Contains:**
- business models (`Tier`, `BonLivraison`, etc.)
- one service per entity holding all its logic (CRUD, queries, validation, multi-table transactions)
- mappers between Drift rows and business models
- shared helpers (PDF, document numbering, backup)

**Does not contain:**
- Flutter widgets
- Drift table definitions

### `db/` — Persistence

Drift database, table definitions, migrations, and connection setup.

**Contains:**
- `AppDatabase`
- table classes
- migrations
- SQLite connection

**Does not contain:**
- UI code
- document workflow rules

---

## What We Deliberately Skip

| Pattern | Reason |
|---------|--------|
| Repository layer | Services can call Drift directly; less boilerplate |
| Global DTO layer | Business models are enough for a local SQLite app |
| Separate domain/presentation folders | Replaced by the simpler 3-folder split |

Add a small UI model inside a feature folder only when a list screen needs extra display fields (e.g. client name on a BL list row).

---

## Recommended Stack

| Concern | Choice |
|---------|--------|
| UI framework | Flutter (mobile-first; Android + desktop) |
| State management | Riverpod |
| Routing | go_router |
| Local database | Drift + SQLite |
| Migrations | Drift `schemaVersion` + `MigrationStrategy` |

---

## Services

**One service per entity/module.** All business logic of that entity goes in its service: list/get, save (header + lines), validation, delete, and multi-table operations (stock movements, payments, status updates), each inside a Drift transaction.

There is **no separate `workflows/` folder** — do not split an entity's logic across several classes.

Examples:
- `tiers_service.dart` — list, get, save, delete tiers
- `bon_livraison_service.dart` — load/save BL, validate, create stock movements, update payment status
- `facture_service.dart` — list/save factures, generate facture from BL lines
- `bon_charge_service.dart` — list/get, save (lines + stock depot → vendor), delete (stock back to depot)
- `stock_movement_service.dart` — shared stock engine (adjustments, depot ↔ depot transfer, document resync) used by the document services

A service may call **shared** services (stock engine, document numbering, locations) but not another entity's service for that entity's own rules.

**Rule:** if an operation touches multiple tables, put it in the entity's service inside `db.transaction`, never in the UI.

---

## Mapping Strategy

Two model types in most places:

```text
Drift row (db/)  →  business model (business/models/)  →  UI
```

Mappers live in `business/mappers/`:

```dart
// business/mappers/bon_livraison_mapper.dart
BonLivraison fromDb(BonLivraisonData row);
BonLivraisonsCompanion toDb(BonLivraison model);
```

Optional third type for complex list screens:

```dart
// ui/livraison/bl_list_item.dart  (only if needed)
class BonLivraisonListItem {
  final int id;
  final String numero;
  final String clientNom;
  final double totalTtc;
  final bool estPayee;
}
```

---

## Navigation (App Shell)

```text
AppShell
 ├── Dashboard
 ├── Tiers
 ├── Stock
 ├── Sales
 │    ├── Devis
 │    ├── Commandes client
 │    ├── Bons livraison
 │    ├── Factures
 │    └── Avoirs
 ├── Purchases
 │    ├── Commandes fournisseur
 │    ├── Bons réception
 │    ├── Factures fournisseur
 │    └── Avoirs fournisseur
 ├── Personnel
 │    ├── Vendeurs
 │    ├── Bons charge
 │    ├── Bons décharge
 │    └── Remises caisse
 ├── Charges
 ├── Reports
 └── Settings
```

---

## Transaction Boundaries

Any operation that updates multiple tables must run in one Drift transaction:

- validate BL + stock movement
- create facture + link BL lines
- bon charge + transfer stock to vendor
- bon décharge + return stock to depot
- supplier payment + update facture status

```dart
await db.transaction(() async {
  // 1. update document
  // 2. update lines
  // 3. insert stock movements
  // 4. update payment status
});
```

Put transaction orchestration in the entity's **service**, not in UI pages.

---

## C# Source Mapping

| C# (Peinture distribution) | Flutter |
|----------------------------|---------|
| `Modules/*/Views` | `ui/` |
| `Modules/*/ViewModels` | UI page state / Riverpod providers |
| `Modules/*/Services` | `business/services/` |
| `*WorkflowService` (e.g. `BonLivraisonWorkflowService`) | merged into the entity service (`business/services/bon_livraison_service.dart`) |
| `Modules/*/Models` | `business/models/` |
| `Shared/Database/AppDbContext` | `db/app_database.dart` |
| `Shared/Database/Migrations` | `db/migrations/` |
| `Shared/Services/*` | `business/services/` |

---

## Starter Scope (Phase 1)

Begin with a minimal subset before building all modules:

```text
lib/
├── main.dart
├── ui/
│   ├── app/
│   ├── tiers/
│   ├── stock/
│   ├── livraison/
│   └── settings/
├── business/
│   ├── models/
│   ├── enums/
│   ├── services/
│   └── mappers/
└── db/
    ├── app_database.dart
    ├── connection.dart
    ├── migrations/
    └── entities/
```

| Phase | Modules |
|-------|---------|
| 1 | auth, tiers, stock, settings |
| 2 | devis, commande_client, livraison |
| 3 | facturation (factures, avoirs) |
| 4 | commande_fournisseur, reception, facture_fournisseur, avoir_fournisseur |
| 5 | personnel, charges |
| 6 | reporting, PDF, backup |

---

## Rules of Thumb

| Question | Answer |
|----------|--------|
| Where does a screen go? | `ui/` |
| Where does a button layout go? | `ui/` |
| Where does "can I validate this BL?" go? | `business/services/bon_livraison_service.dart` |
| Where does save/load logic go? | `business/services/` |
| Where does a `BonLivraison` class go? | `business/models/` |
| Where does a Drift table go? | `db/entities/` |
| Where does a migration go? | `db/migrations/` |
| When to add a UI list model? | Only when the screen needs joined/display-only fields |

---

## Related Documentation

- [Database Design](./database-design.md) — full schema, tables, enums, and relationships
- [Flutter Setup & Roadmap](./flutter-setup.md) — dependencies, Drift bootstrap, project creation (reference: TangerAppAndroid)

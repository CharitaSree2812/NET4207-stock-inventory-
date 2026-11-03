# NET4207 Stock Inventory Manager

A Flutter stock inventory app that stores and retrieves stock records using Firebase Cloud Firestore.

## 1. Project setup

**Firebase Project ID:** `net4207-stock-inventory-992e3`

1. Install Flutter and verify the installation with `flutter doctor`.
2. Install Node.js and npm, then install and sign in to Firebase CLI:
   ```bash
   npm install -g firebase-tools
   firebase login
   ```
3. Install FlutterFire CLI and configure this project:
   ```bash
   dart pub global activate flutterfire_cli
   dart pub global run flutterfire_cli:flutterfire configure --project=net4207-stock-inventory-992e3
   ```
4. Select **Android** and **Web** when prompted. This generates `lib/firebase_options.dart`.
5. In the Firebase Console, create the default Cloud Firestore database.
6. From the project root, install packages and run the app:
   ```bash
   flutter pub get
   flutter run -d chrome
   ```
   Use `flutter run` to run on a connected Android device or emulator.

Do not upload service-account JSON files, passwords, private keys, or other credentials. The generated Firebase app configuration is required by this project.

## 2. Packages

- `firebase_core` — initializes Firebase.
- `cloud_firestore` — writes and retrieves inventory records.

## 3. Firestore data schema

Collection: `stockItems`. Firestore generates each document ID.

| Field | Type | Requirement |
|---|---|---|
| `sku` | String | `STK-` followed by exactly three digits |
| `itemName` | String | Trimmed; at least 3 characters |
| `category` | String | Electronics, Stationery, Hardware, or Grocery |
| `quantity` | Integer | Whole number, 0 or above |
| `unitPrice` | Number | Greater than RM 0 |
| `reorderLevel` | Integer | Whole number, 0 or above |
| `createdAt` | Timestamp | Firestore server timestamp |

## 4. Validation and inventory search

The entry form uses `GlobalKey<FormState>` and field-level validators. It checks the SKU format, item-name length, required category, non-negative whole-number quantity and reorder level, and a positive unit price. The Firestore write is attempted only after validation succeeds.

The inventory list reads saved documents from Firestore. Keyword search is partial and case-insensitive across `itemName` or `sku`. Category, keyword, and low-stock filters work together using AND logic. Low stock means `quantity <= reorderLevel`. Results can be sorted by quantity in ascending or descending order, and **Clear Filters** restores the full list.

## 5. Acceptance data

| SKU | Item name | Category | Qty | Price (RM) | Reorder |
|---|---|---|---:|---:|---:|
| STK-101 | USB C Cable | Electronics | 4 | 19.90 | 5 |
| STK-102 | Notebook | Stationery | 25 | 4.50 | 10 |
| STK-103 | Wireless Mouse | Electronics | 1 | 35.00 | 3 |

## 6. Test log

The actual results below reflect the tests demonstrated in the running application and Firestore Console.

| Test | Expected result | Actual result |
|---|---|---|
| Submit the blank form | Inline errors; invalid form is not saved | Field-level errors appeared for all six required fields. |
| Submit malformed values (`ABC`, `AB`, quantity `-1`, price `0`, reorder level `-2`) | Specific validation errors | SKU, name, category, quantity, price, and reorder-level errors appeared. |
| Submit decimal quantity `2.5` and reorder level `1.5` | Whole-number validation errors | Both fields displayed “must be a whole number.” |
| Save the three acceptance records | Three records saved and retrievable with the required fields and timestamp | All three records appeared in the app and in the Firestore `stockItems` collection; the displayed values and timestamps were checked. |
| Search `mouse` + Electronics + Low stock ON | Only STK-103 appears | Only Wireless Mouse (STK-103) appeared. |
| Search `STK-102` with All and Low stock OFF | Notebook appears | Only Notebook (STK-102) appeared. |
| Sort by quantity descending | STK-102, STK-101, STK-103 | The list appeared in that order. |
| Clear filters | Full inventory list appears | Search cleared, category returned to All, low-stock filter turned OFF, and all three records appeared. |

## 7. Evidence and GitHub submission

Add screenshots of the blank-form validation, malformed-value validation, decimal validation, three saved inventory records, combined search, SKU search, sorting, and the Firestore documents. Commit the Flutter source, this `README.md`, and the evidence screenshots to GitHub.

The Firestore rules used for this classroom test allow reads and creates in `stockItems` until **3 December 2026**. These temporary rules are not suitable for a production application; replace them with appropriately restricted rules before any real deployment.

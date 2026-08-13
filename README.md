# TaskPoint Admin (Flutter Web)

Internal admin dashboard, separate from the seeker/provider app, sharing the
same Firebase project (`taskpoint-8aba0`) so both apps read and write the
same data.

## What's here

All eight modules are wired to Firestore and working:

| Module | Reads | Actions |
| --- | --- | --- |
| **Dashboard** | live aggregate counts across all queues | click a card to jump to that module |
| **CNIC Verifications** | `users` where `cnicStatus == 'pending'` | Approve → `verified`, Reject → `rejected` + reason |
| **Wallet Top-Ups** | `wallet_topups` by status | Approve → credits `walletBalance` and settles the ledger row, atomically; Reject |
| **Reports** | `reports` by status | Resolve / Dismiss / Reopen |
| **SOS Alerts** | `sos_logs` by `resolved` | Mark resolved, with a maps link to the coordinates |
| **Users** | `users`, filterable by role, searchable | Suspend / Restore |
| **Jobs** | `jobs`, filterable by status | Force-cancel for disputes |
| **Categories** | `categories` | Full add / edit / delete / reorder |

Layout:

- `lib/models/admin_models.dart` — read-side models mirroring the mobile
  app's Firestore documents. **Keep in step with the mobile app's services**;
  the two apps share one database.
- `lib/models/category_icons.dart` — copy of the mobile app's
  `categoryIconFor()` so the icon an admin picks is the icon seekers see.
- `lib/services/*.dart` — one service class per module, each documenting the
  exact query or write it performs. Screens call services; no raw Firestore
  in widget code.
- `lib/screens/sections/*.dart` — one screen per module.
- `lib/widgets/admin_widgets.dart` — shared chrome (section frame, status
  pills, filter tabs, image preview, reason prompt).
- `lib/theme/app_theme.dart` — copied from the mobile app so the look
  matches. Keep both in sync if you change one.

## Setup

1. **Install deps:**
   ```
   flutter pub get
   ```

2. **Publish the Firestore rules.** This is required — the dashboard cannot
   work without it.

   The rules live in the *mobile* project (`taskpoint/firestore.rules`), and
   they now define the `admins` collection plus an `isAdmin()` clause on
   every collection this dashboard touches. Before that was added, `admins`
   fell under no rule at all, so it was denied by default and **admin
   sign-in could never succeed** — every login failed with
   `permission-denied`.

   From the `taskpoint/` folder:
   ```
   firebase deploy --only firestore:rules
   ```

3. **Create your first admin.** Firebase Auth has no built-in concept of
   "admin" — that's what the `admins` collection is for:
   - Firebase console → Authentication → Users → Add user (email + password).
   - Copy that user's UID.
   - Firestore → create document `admins/{that UID}` with:
     ```
     name: "Your Name"
     role: "super_admin"
     addedAt: <timestamp>
     ```

   The rules make `admins` **read-only from every client** on purpose: an
   admin account that gets compromised still can't mint more admins. Add
   them in the console.

4. **Run it:**
   ```
   flutter run -d chrome
   ```

## How this connects to the mobile app

The dashboard isn't a separate system — several mobile flows are inert
without it:

- **CNIC** — `CnicService.submit()` sets `cnicStatus: 'pending'`. Only this
  dashboard moves it to `verified` / `rejected`. A rejection reason written
  here is shown back on the mobile CNIC screen.
- **Wallet top-ups** — `WalletService.submitTopUp()` deliberately does *not*
  credit the balance; it records a `pending` request plus a `pending` ledger
  row carrying a `topupId` back-reference. Approving here is the only thing
  in either app that credits a wallet from a bank transfer.
- **Suspension** — `users/{uid}.suspended` is watched live by the mobile
  `SessionController`, which signs that device straight out and shows the
  suspension reason. It takes effect immediately, not on next launch.
- **SOS** — the mobile app can't send SMS or dial out (device-level actions
  Firebase can't perform), so this queue is the only way an emergency alert
  reaches a human.

## Notes

- **Images** (CNIC photos, transfer proofs) render from the Firebase Storage
  *download URLs* stored on the documents. Those URLs carry their own access
  token, so the dashboard can display them without Storage rules granting
  admins blanket read access to everyone's CNIC folder — which is why
  `storage.rules` needed no changes.
- **Queries avoid new composite indexes.** Where a status filter would need
  pairing with `orderBy`, the sort is done client-side over a bounded page
  instead, so the modules work without deploying extra indexes first.
- `src/src/firebase.js` and `package.json` are leftovers from an abandoned
  JS-SDK start; nothing in the Flutter app imports them.

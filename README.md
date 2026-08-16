# Money Tracker

A personal finance app built with Flutter and Firebase — designed to feel warm and personal rather than like a corporate utility. Track monthly spending across budget buckets, manage savings goals with a jar visualization, monitor recurring bills, and get a clear picture of where your money goes each month.

> **Private repo** — contains `firebase_options.dart` with the Firebase project ID. Keep private until Firestore security rules are fully locked down.

---

## Features

### 🏠 Dashboard
- **Forest-green balance card** showing remaining balance, income, and total spent for the selected month
- **Swipe left/right** on the hero card to navigate between months (arrow buttons also work)
- **Bills checklist** — recurring commitments (Chit Fund, Hostel Fee, Mutual Fund SIP, etc.) shown as a tappable checklist; ones already logged this month get a colored checkmark
- **Spending donut chart** — segmented by budget bucket with a legend; month total shown in the center
- **Quick Add strip** — all categories as horizontally scrollable cards; tap any to log instantly
- **Goal jar cards** — horizontal row of savings goals visualized as filling jars with a wave animation
- **Recent transactions** — last 6 entries, each tappable to edit

### ➕ Quick Add (Log Expense)
- Large numpad with a **blinking cursor** in the amount field
- Category picker grouped by bucket with colored icons
- Optional note and date picker (defaults to today)
- Pre-fills default amount for recurring categories
- Same sheet used for **editing** existing transactions

### 🗂️ Categories
- 24 seed categories across 6 budget buckets
- Full **CRUD**: create, edit, and delete categories
- Per-category settings: budget bucket, icon (25 options), recurring toggle, default amount, pin to Quick Add strip
- Long-press any category card for a context menu (Log Spend / Pin / Edit / Delete)

### 💸 Transactions
- Month-by-month view with ← → navigation
- Transactions grouped by date with day totals
- **Tap** any transaction to edit it
- **⋮ menu** on each card for Edit and Delete — works on both mobile and web (no swipe required)
- Swipe-to-delete also supported on mobile

### 📊 Reports
- Month selector in the curved header
- **Balance hero card** — income, total spent, and remaining at a glance
- **Savings rate** and **Family Support %** insight chips
- Spending breakdown by bucket with progress bars
- Spending breakdown by individual category

### 🎯 Goals
- Add savings goals with an emoji, target amount, and already-saved amount
- Each goal visualized as a **filling jar** with an encouraging line (*"Halfway there! ⭐"*)
- **Add Money** — increment the saved amount
- **Correct** — set the exact saved amount if you entered it wrong
- **Edit** or **Delete** via a ⋮ menu on every goal card
- Active and Completed goals shown in separate sections

### ⚙️ Settings
- Set or update monthly income (per month — different months can have different salaries)
- Generate recurring entries for the selected month in one tap (Chit Fund, Hostel Fee, SIP, etc.)
- Account info and sign-out

---

## Budget Buckets

The app uses 6 buckets to categorize every expense:

| Bucket | Color | Examples |
|---|---|---|
| 🏠 Fixed Needs | Soft blue | Hostel Fee, Phone Recharge |
| 🛒 Daily Needs | Soft green | Groceries, Metro, Food |
| 👨‍👩‍👧 Family | Soft coral | Sibling's Fee, Family Recharge, Gifts |
| 📈 Savings | Soft teal | Chit Fund, Mutual Fund SIP |
| 💳 Debt | Soft lavender | Debt EMI |
| 🎉 Discretionary | Soft amber | Dining Out, Shopping, Entertainment |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x (Dart) |
| Backend | Firebase Firestore (with offline persistence) |
| Auth | Firebase Auth + Google Sign-In (`signInWithPopup` on web) |
| State management | Riverpod 2.x — `StreamProvider`, `FutureProvider`, `StateProvider` |
| Fonts | Google Fonts — Nunito (body), Pacifico (display) |
| Number formatting | `intl` — Indian locale (`#,##,##0`) |
| Platforms | Android, iOS, Web (Chrome) |

---

## Firestore Data Model

All data lives under `users/{uid}/` so each account is fully isolated.

```
users/{uid}/
├── categories/        # AppCategory documents
│   ├── name, bucket, icon_key
│   ├── is_recurring, default_amount
│   └── is_pinned, sort_order
│
├── transactions/      # MoneyTransaction documents
│   ├── category_id, category_name, bucket
│   ├── amount, note, date
│   └── created_from_recurring (bool)
│
├── goals/             # Goal documents
│   ├── name, emoji
│   ├── target_amount, saved_amount
│   └── target_date (nullable)
│
└── income/            # Monthly income documents
    ├── {YYYY-MM}      # e.g. "2026-08" → { amount: 79120 }
    └── default        # fallback if no month-specific record
```

---

## Project Structure

```
lib/
├── main.dart                     # App entry, theme (forest green + Nunito)
├── firebase_options.dart         # Firebase config (DO NOT commit to public repos)
│
├── models/
│   ├── app_category.dart         # AppCategory model, bucket colors, icon map, seed data
│   ├── transaction.dart          # MoneyTransaction model
│   └── goal.dart                 # Goal model with progress/remaining getters
│
├── providers/
│   └── providers.dart            # All Riverpod providers
│                                 #   selectedMonthProvider (global shared month state)
│                                 #   categoriesProvider, monthTransactionsProvider
│                                 #   monthExpenseTotalProvider, monthBucketTotalsProvider
│                                 #   monthlyIncomeProvider, goalsProvider
│
├── services/
│   ├── firestore_service.dart    # All Firestore reads/writes + seedIfEmpty()
│   └── auth_service.dart         # Google Sign-In / Sign-Out
│
└── screens/
    ├── auth/                     # AuthGate (stream-based), LoginScreen
    ├── dashboard/                # Dashboard with donut chart, jar goals, bills checklist
    ├── add/                      # QuickAddSheet (shared for add + edit)
    ├── categories/               # CategoriesScreen + CategoryFormSheet (CRUD)
    ├── transactions/             # TransactionsScreen with month nav + ⋮ menu
    ├── reports/                  # ReportsScreen with bucket breakdown
    ├── goals/                    # GoalsScreen with jar visualization
    └── settings/                 # Income setting, recurring entries, sign-out
```

---

## Getting Started

### Prerequisites
- Flutter SDK ≥ 3.9
- A Firebase project with **Firestore** and **Authentication** (Google provider) enabled
- For web: OAuth authorized domain and redirect URI configured in Google Cloud Console

### Setup

1. **Install dependencies**
   ```bash
   flutter pub get
   ```

2. **Add Firebase config files** (not committed — keep these private)
   ```
   android/app/google-services.json
   ios/Runner/GoogleService-Info.plist
   ```

3. **Run the app**
   ```bash
   # Android / iOS
   flutter run

   # Web (port must match OAuth authorized redirect URI)
   flutter run -d chrome --web-port 5000

   # Release APK
   flutter build apk --release
   ```

### First launch
On first sign-in the app seeds 24 default categories, a default income of ₹79,120, and a sample "Gold Ring" savings goal. All of this is editable — delete or rename anything from the Categories and Goals screens.

---

## Security

| File | Status | Reason |
|---|---|---|
| `android/app/google-services.json` | ✅ In `.gitignore` | Contains Firebase API key |
| `ios/Runner/GoogleService-Info.plist` | ✅ In `.gitignore` | Contains Firebase API key |
| `lib/firebase_options.dart` | ⚠️ Committed | Contains project ID — keep repo **private** |

Before making the repo public, replace the hardcoded Firebase config with environment variables or a secrets manager, and lock down Firestore security rules to `request.auth.uid == resource.data.uid`.

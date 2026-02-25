# Split It

A modern expense-splitting app built with Flutter for **Huawei AppGallery**. Track shared costs in groups, simplify debts, and settle up easily — powered entirely by Huawei Mobile Services (HMS).

## Features

- **Groups** — Create groups, add members, track shared expenses
- **Expenses** — Add expenses with equal split, view breakdowns, delete
- **Settlements** — Record payments between members
- **Balance Calculator** — Automatic debt simplification (minimizes transactions)
- **Friends** — Manage friends list with balance tracking
- **Activity Feed** — Timeline of all expenses across groups
- **Auth** — Email/password registration (with verify code), Huawei ID sign-in, forgot password
- **Profile** — View and edit display name
- **Dark Mode** — Full light/dark theme support with persistence

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart) |
| State Management | Riverpod |
| Navigation | GoRouter |
| Auth | AGConnect Auth (Email/Password + Huawei ID) |
| Database | AGConnect Cloud DB |
| Local Storage | Hive |
| Signing | JKS keystore for AppGallery |

## Project Structure

```
lib/
├── main.dart                          # Entry point
├── app.dart                           # MaterialApp.router
├── core/
│   ├── providers/theme_provider.dart  # Dark mode persistence
│   ├── router/                        # GoRouter config + route constants
│   ├── services/cloud_db_service.dart # Cloud DB wrapper
│   ├── theme/                         # Colors + light/dark themes
│   └── utils/balance_calculator.dart  # Debt simplification
├── features/
│   ├── auth/           # Login, register, forgot password, splash
│   ├── groups/         # List, create, detail (balances + add member)
│   ├── expenses/       # Add expense, detail, (scan receipt placeholder)
│   ├── friends/        # List, add, detail with shared expenses
│   ├── settle/         # Record settlements between members
│   ├── activity/       # Expense timeline across all groups
│   ├── account/        # Profile, settings
│   └── home/           # Bottom navigation shell (4 tabs)
└── shared/models/      # AppUser, Group, Expense, Friend, Settlement
```

## Getting Started

### Prerequisites

- Flutter SDK
- Android SDK
- Huawei AppGallery Connect project with Auth + Cloud DB enabled

### Setup

```bash
git clone https://github.com/yourusername/split_it.git
cd split_it
flutter pub get
```

### Configuration

1. Place your `agconnect-services.json` in `android/app/`
2. Place your `split_it.jks` keystore in the project root
3. Create `android/key.properties`:
   ```properties
   storePassword=your_password
   keyPassword=your_password
   keyAlias=your_key_alias
   storeFile=../../split_it.jks
   ```

4. Set up Cloud DB Object Types in AppGallery Connect console:
   - **Group** (id, name, description, imageURL, createdBy, createdAt, memberIds, currency)
   - **Expense** (id, groupId, description, amount, paidBy, date, split, imageURL, createdBy)
   - **Friend** (id, userId1, userId2, balance, friendName, friendEmail, friendImageUrl)
   - **Settlement** (id, groupId, paidBy, paidTo, amount, date, note)

### Run

```bash
flutter run                        # Debug
flutter build apk --release        # Release APK (signed)
flutter analyze --no-fatal-infos   # Lint check
```

## Architecture

- **Clean Architecture** with feature-based modules
- **Riverpod** for state management (`StateNotifier`, `FutureProvider`, `FutureProvider.family`)
- **GoRouter** with auth redirect (unauthenticated → login, authenticated → groups)
- **Cloud DB** with `SplitItZone` (cloud cache, public access, persistence enabled)
- **Balance calculation** uses greedy debt simplification algorithm

## Key Dependencies

| Package | Purpose |
|---------|---------|
| flutter_riverpod | State management |
| go_router | Declarative routing |
| agconnect_auth | HMS Authentication |
| agconnect_clouddb | HMS Cloud Database |
| huawei_account | Huawei ID sign-in |
| hive_flutter | Local caching |
| shared_preferences | Theme persistence |
| intl | Date formatting |
| equatable | Value equality for models |

## Status

**Current**: Core features complete and functional.

**Remaining**:
- Scan Receipt / OCR integration
- Custom expense split (unequal amounts)
- Notification system
- Privacy Policy & Terms of Service pages

---

**Last Updated**: February 2026

<div align="center">

# 💸 Split It

**The smart expense-splitting app for Huawei AppGallery**

Split bills, track shared expenses, simplify debts, and settle up with friends — all powered by Huawei Mobile Services.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![HMS](https://img.shields.io/badge/Huawei-HMS-FF0000?logo=huawei&logoColor=white)](https://developer.huawei.com/consumer/en/hms/)
[![AppGallery](https://img.shields.io/badge/Huawei-AppGallery-FF0000?logo=huawei&logoColor=white)](https://appgallery.huawei.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 👥 **Groups** | Create groups, add members, track shared expenses with balance summaries |
| 💰 **Expense Splitting** | Add expenses with equal split, view detailed breakdowns per person |
| 🤝 **Settlements** | Record payments between members to clear debts |
| 📊 **Smart Balances** | Automatic debt simplification — minimizes the number of transactions needed |
| 👫 **Friends** | Manage a friends list with running balance tracking |
| 📱 **Activity Feed** | Real-time timeline of all expenses across every group |
| 🔐 **Secure Auth** | Email/password with verification, Huawei ID one-tap sign-in, password reset |
| 👤 **Profile Management** | View and edit your display name |
| 🌙 **Dark Mode** | Full light and dark theme support with automatic persistence |

---

## 🛠 Tech Stack

| Layer | Technology |
|-------|-----------|
| **Framework** | [Flutter](https://flutter.dev) (Dart) |
| **State Management** | [Riverpod](https://riverpod.dev) |
| **Navigation** | [GoRouter](https://pub.dev/packages/go_router) |
| **Authentication** | AGConnect Auth (Email/Password + Huawei ID) |
| **Database** | AGConnect Cloud DB (NoSQL) |
| **Local Storage** | [Hive](https://pub.dev/packages/hive_flutter) |
| **Architecture** | Clean Architecture with feature-based modules |

---

## 📁 Project Structure

```
lib/
├── main.dart                          # Entry point — initializes services
├── app.dart                           # MaterialApp.router with theming
├── core/
│   ├── providers/theme_provider.dart  # Dark mode with SharedPreferences
│   ├── router/                        # GoRouter config + auth redirect
│   ├── services/cloud_db_service.dart # AGConnect Cloud DB wrapper
│   ├── theme/                         # AppColors + light/dark themes
│   └── utils/balance_calculator.dart  # Greedy debt simplification algorithm
├── features/
│   ├── auth/           # Login, register, forgot password, splash
│   ├── groups/         # List, create, detail (balances + members)
│   ├── expenses/       # Add expense, detail view, delete
│   ├── friends/        # Friends list, add friend, detail
│   ├── settle/         # Record settlements between members
│   ├── activity/       # Expense timeline across all groups
│   ├── account/        # Profile editing, settings
│   └── home/           # Bottom navigation shell (4 tabs)
└── shared/models/      # AppUser, Group, Expense, Friend, Settlement
```

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** (3.x or later)
- **Android SDK** (API 24+)
- **Huawei AppGallery Connect** project with Auth + Cloud DB enabled

### Installation

```bash
# Clone the repository
git clone https://github.com/SherryKhwan/split_it.git
cd split_it

# Install dependencies
flutter pub get
```

### Configuration

1. **AGConnect config** — Place `agconnect-services.json` in `android/app/`

2. **Signing keystore** — Place your `.jks` file in the project root

3. **Key properties** — Create `android/key.properties`:
   ```properties
   storePassword=your_store_password
   keyPassword=your_key_password
   keyAlias=your_key_alias
   storeFile=../../your_keystore.jks
   ```

4. **Cloud DB setup** — Create these Object Types in AppGallery Connect console:

   | Object Type | Primary Key | Other Fields |
   |-------------|:-----------:|-------------|
   | **Group** | `id` (String) | name, description, imageURL, createdBy, createdAt, memberIds, currency |
   | **Expense** | `id` (String) | groupId, description, amount, paidBy, date, split, imageURL, createdBy |
   | **Friend** | `id` (String) | userId1, userId2, balance, friendName, friendEmail, friendImageUrl |
   | **Settlement** | `id` (String) | groupId, paidBy, paidTo, amount, date, note |

### Run

```bash
flutter run                        # Debug build
flutter build apk --release        # Release APK (auto-signed)
flutter analyze --no-fatal-infos   # Lint check
```

---

## 🏗 Architecture

Split It follows **Clean Architecture** with feature-based modules:

```
Feature Module
├── data/           # Repository (Cloud DB operations)
├── providers/      # Riverpod state management
└── presentation/
    └── screens/    # UI (ConsumerWidget / ConsumerStatefulWidget)
```

**Key architecture decisions:**

- **Riverpod** — `StateNotifier` for mutations, `FutureProvider.family` for parameterized queries
- **GoRouter** — Centralized auth redirect (unauthenticated → login, authenticated → groups)
- **Cloud DB** — `SplitItZone` with cloud cache sync, public access, persistence enabled
- **Balance calculation** — Greedy algorithm that minimizes the number of transactions to settle all debts
- **JSON serialization** — Complex fields (`memberIds`, `split`) stored as JSON strings in Cloud DB

---

## 📦 Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | Reactive state management |
| `go_router` | Declarative routing with auth guards |
| `agconnect_auth` | HMS authentication service |
| `agconnect_clouddb` | HMS cloud NoSQL database |
| `huawei_account` | Huawei ID one-tap sign-in |
| `hive_flutter` | Fast local key-value storage |
| `shared_preferences` | Theme mode persistence |
| `intl` | Date and number formatting |
| `equatable` | Value equality for data models |

---

## 📋 Roadmap

- [x] Email/password authentication with verification
- [x] Huawei ID sign-in
- [x] Group creation and management
- [x] Expense tracking with equal split
- [x] Settlement recording
- [x] Debt simplification algorithm
- [x] Friends management
- [x] Activity feed
- [x] Dark mode with persistence
- [x] Forgot password flow
- [ ] Receipt scanning with OCR (ML Kit)
- [ ] Custom expense splits (unequal amounts)
- [ ] Push notifications for expense reminders
- [ ] In-app privacy policy and terms of service

---

## 🔒 Privacy

Split It is built with privacy-by-design principles. We don't sell data, don't run ads, and don't track users. See our full [Privacy Policy](PRIVACY_POLICY.md).

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**Built with ❤️ using Flutter & Huawei Mobile Services**

*Split bills. Simplify debts. Stay friends.*

</div>

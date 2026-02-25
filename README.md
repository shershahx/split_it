<div align="center">

# 💸 Split It

### The Smart Way to Split Bills with Friends

Split expenses, track who owes what, simplify debts, and settle up — all from one app on **Huawei AppGallery**.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![HMS](https://img.shields.io/badge/Powered%20by-Huawei%20HMS-FF0000?logo=huawei&logoColor=white)](https://developer.huawei.com/consumer/en/hms/)
[![AppGallery](https://img.shields.io/badge/Available%20on-AppGallery-FF0000?logo=huawei&logoColor=white)](https://appgallery.huawei.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Expense Splitter • Debt Tracker • Bill Divider • Group Finance Manager**

</div>

---

## 🤔 What Is Split It?

Split It is a **free, privacy-first expense splitting app** built for Huawei devices. Whether you're sharing rent with roommates, splitting a dinner bill, or managing trip expenses with friends — Split It handles the math so you don't have to.

> **No ads. No data selling. No tracking.** Just clean, simple expense splitting.

---

## ✨ What Can You Do?

### 👥 Create Groups
Organize expenses by trip, household, event, or anything else. Add members and everyone can see what's owed at a glance.

### 💰 Split Expenses Instantly
Add an expense, pick who paid, and Split It divides it equally among the group. See exactly who owes what, down to the cent.

### 📊 Smart Debt Simplification
Owe Alice $20 and Bob owes you $15? Split It's algorithm minimizes the number of payments needed — fewer transactions, less hassle.

### 🤝 Settle Up
Record payments between members. Watch your balances go to zero as debts get cleared.

### 👫 Track Friends
Keep a running balance with friends across all your groups. One screen to see everything.

### 📱 Activity Feed
A real-time timeline of every expense across every group — so nothing gets missed.

### 🔐 Secure Sign-In
Sign in with your email (verified) or tap once with your **Huawei ID**. Forgot your password? Reset it right in the app.

### 🌙 Dark Mode
Toggle between light and dark themes. Your preference is saved automatically.

---

## 📸 How It Works

1. **Sign up** with your email or Huawei ID
2. **Create a group** (e.g., "Weekend Trip", "Apartment")
3. **Add expenses** — enter an amount and who paid
4. **See balances** — the app calculates who owes whom
5. **Settle up** — record payments and clear debts

---

## 🛠 Built With

| | Technology | Role |
|---|-----------|------|
| 💙 | **Flutter & Dart** | Cross-platform UI framework |
| 🔄 | **Riverpod** | Reactive state management |
| 🗺️ | **GoRouter** | Navigation with auth guards |
| 🔑 | **AGConnect Auth** | Secure authentication (Email + Huawei ID) |
| ☁️ | **AGConnect Cloud DB** | Real-time cloud database |
| 📦 | **Hive** | Fast local caching |
| 🏗️ | **Clean Architecture** | Feature-based modular structure |

---

## 📋 Roadmap

### ✅ Available Now
- Email/password sign-in with email verification
- Huawei ID one-tap sign-in
- Group creation and member management
- Expense tracking with equal split
- Settlement recording
- Automatic debt simplification
- Friends list with balances
- Activity feed
- Dark mode
- Password reset

### 🔜 Coming Soon
- 📷 Receipt scanning with on-device OCR
- ⚖️ Custom expense splits (unequal amounts)
- 🔔 Push notifications for expense reminders
- 📄 In-app privacy policy viewer

---

## 🔒 Your Privacy Matters

Split It is built with **privacy-by-design**:

- ✅ No ads, ever
- ✅ No data sold to third parties
- ✅ No tracking or analytics cookies
- ✅ All data encrypted in transit (HTTPS/TLS)
- ✅ Authentication handled by Huawei's secure AGConnect platform
- ✅ GDPR and CCPA compliant

Read our full [Privacy Policy](PRIVACY_POLICY.md).

---

## 🚀 For Developers

### Quick Start

```bash
git clone https://github.com/SherryKhwan/split_it.git
cd split_it
flutter pub get
flutter run
```

### Architecture

```
lib/
├── core/        # Router, theme, services, utilities
├── features/    # Auth, groups, expenses, friends, settle, activity, account
└── shared/      # Data models (Group, Expense, Friend, Settlement)
```

Each feature follows Clean Architecture: `data/` → `providers/` → `presentation/screens/`.

### Commands

```bash
flutter run                        # Debug build
flutter build apk --release        # Signed release APK
flutter analyze --no-fatal-infos   # Lint check (0 errors)
```

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

<div align="center">

**Built with ❤️ using Flutter & Huawei Mobile Services**

*Split bills. Simplify debts. Stay friends.*

[![GitHub](https://img.shields.io/badge/GitHub-shershahx-181717?logo=github&logoColor=white)](https://github.com/shershahx)

</div>

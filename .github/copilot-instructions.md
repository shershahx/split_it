# Split It - AI Coding Instructions

## Architecture Overview

This is a **Flutter expense-splitting app** using Clean Architecture with feature-based modules. The scaffold is complete but features are placeholder implementations awaiting business logic.

### Project Structure
```
lib/
├── core/           # Shared infrastructure (router, theme, providers)
├── features/       # Feature modules (auth, groups, friends, expenses, etc.)
│   └── {feature}/
│       ├── presentation/screens/   # UI screens
│       └── providers/              # Riverpod state (when needed)
└── shared/         # Reusable widgets, models, utils (to be built)
```

## Key Patterns

### State Management: Riverpod
- Use `ConsumerWidget` or `ConsumerStatefulWidget` for widgets that need state
- Define providers in `features/{feature}/providers/`
- Reference: [auth_provider.dart](lib/features/auth/providers/auth_provider.dart)

```dart
// Pattern: StateProvider for simple state
final authStateProvider = StateProvider<String?>((ref) => null);

// Usage in widgets
class MyWidget extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(myProvider);
    ref.read(myProvider.notifier).state = newValue;  // Update
  }
}
```

### Navigation: GoRouter
- Routes defined in [app_router.dart](lib/core/router/app_router.dart)
- Route constants in [app_routes.dart](lib/core/router/app_routes.dart)
- Auth redirect logic is centralized in the router's `redirect` callback

```dart
context.go('/groups');                    // Replace
context.push('/groups/123/add-expense');  // Push (back supported)
context.goNamed('group-detail', pathParameters: {'groupId': '123'});
```

### Theming
- Colors: Use `AppColors.primary`, `AppColors.positiveBalance`, etc. from [app_colors.dart](lib/core/theme/app_colors.dart)
- Themes: Light/dark defined in [app_theme.dart](lib/core/theme/app_theme.dart)
- Typography: Poppins for headings, Inter for body (via Google Fonts)

```dart
AppColors.positiveBalance  // Green - you are owed
AppColors.negativeBalance  // Red - you owe  
AppColors.getAvatarColor(name)  // Consistent avatar colors
```

### Screen Pattern
Screens are stateless placeholders. When implementing, use:
- `ConsumerWidget` for Riverpod integration
- Required parameters passed via constructor (e.g., `groupId`)
- AppBar with consistent styling via theme

## Commands

```bash
flutter run                  # Run debug build
flutter pub get              # Install dependencies
flutter analyze              # Check for issues
flutter test                 # Run tests
```

## Firebase Integration
- Firebase is initialized in [main.dart](lib/main.dart)
- Requires `android/app/google-services.json` (not committed)
- Services used: Auth, Firestore, Storage, Messaging

## Dependencies of Note
| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management |
| `go_router` | Declarative routing |
| `google_mlkit_text_recognition` | Receipt OCR (on-device) |
| `fl_chart` | Expense charts |
| `hive_flutter` | Local caching |

## Development Status
The scaffold is 100% complete. Features need implementation:
1. **Firebase Auth** - Email/password + Google Sign-In
2. **Firestore models** - Groups, expenses, settlements
3. **Business logic** - Debt simplification algorithm, balance calculations

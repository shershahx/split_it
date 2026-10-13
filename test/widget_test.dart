import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_it/app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'sb_publishable_test',
    );
  });

  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SplitItApp()));
    await tester.pump();

    expect(find.byType(SplitItApp), findsOneWidget);
  });
}

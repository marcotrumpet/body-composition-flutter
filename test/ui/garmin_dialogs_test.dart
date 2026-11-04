import 'package:body_composition_flutter/ui/body_theme.dart';
import 'package:body_composition_flutter/ui/garmin_dialogs.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _launcher({
  required Future<void> Function(BuildContext) onPressed,
  required String label,
  required TargetPlatform platform,
}) {
  return MaterialApp(
    theme: BodyTheme.light().copyWith(platform: platform),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => onPressed(context),
            child: Text(label),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Garmin login validates the password and returns credentials', (
    tester,
  ) async {
    GarminCredentials? result;
    await tester.pumpWidget(
      _launcher(
        label: 'connect',
        platform: TargetPlatform.android,
        onPressed: (context) async {
          result = await showGarminLoginDialog(
            context,
            initialEmail: 'rider@example.com',
          );
        },
      ),
    );

    await tester.tap(find.text('connect'));
    await tester.pumpAndSettle();
    expect(find.text('Connect Garmin'), findsOneWidget);
    expect(find.text('rider@example.com'), findsOneWidget);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your Garmin password.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, 'secret');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Connect Garmin'), findsNothing);
    expect(result?.email, 'rider@example.com');
    expect(result?.password, 'secret');
  });

  testWidgets('Garmin login rejects a malformed email', (tester) async {
    await tester.pumpWidget(
      _launcher(
        label: 'connect',
        platform: TargetPlatform.android,
        onPressed: (context) async {
          await showGarminLoginDialog(context);
        },
      ),
    );

    await tester.tap(find.text('connect'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.enterText(find.byType(TextFormField).last, 'secret');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('Garmin MFA explains the delivery method and returns the code', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      _launcher(
        label: 'verify',
        platform: TargetPlatform.android,
        onPressed: (context) async {
          result = await showGarminMfaDialog(
            context,
            method: 'email',
            email: 'rider@example.com',
          );
        },
      ),
    );

    await tester.tap(find.text('verify'));
    await tester.pumpAndSettle();
    expect(find.textContaining('emailed you'), findsOneWidget);
    expect(find.textContaining('Sent to rider@example.com'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(result, '123456');
  });

  testWidgets('iOS Garmin login sheet returns credentials', (tester) async {
    GarminCredentials? result;
    await tester.pumpWidget(
      _launcher(
        label: 'connect',
        platform: TargetPlatform.iOS,
        onPressed: (context) async {
          result = await showGarminLoginDialog(context);
        },
      ),
    );

    await tester.tap(find.text('connect'));
    await tester.pumpAndSettle();
    expect(find.text('Garmin account'), findsOneWidget);

    final fields = find.byType(CupertinoTextField);
    await tester.enterText(fields.at(0), 'rider@example.com');
    await tester.enterText(fields.at(1), 'secret');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(result?.email, 'rider@example.com');
    expect(result?.password, 'secret');
  });
}

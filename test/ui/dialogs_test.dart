import 'package:body_composition_flutter/models/user_profile.dart';
import 'package:body_composition_flutter/ui/body_theme.dart';
import 'package:body_composition_flutter/ui/dialogs.dart';
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

  group('Material dialogs', () {
    testWidgets('profile dialog validates inline and returns a profile',
        (tester) async {
      UserProfile? result;
      await tester.pumpWidget(
        _launcher(
          label: 'open-profile',
          platform: TargetPlatform.android,
          onPressed: (context) async {
            result = await showProfileDialog(context);
          },
        ),
      );

      await tester.tap(find.text('open-profile'));
      await tester.pumpAndSettle();
      expect(find.text('Measurement profile'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));

      await tester.enterText(find.byType(TextFormField).at(0), '50');
      await tester.enterText(find.byType(TextFormField).at(1), '35');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Height must be between 100 and 250 cm.'),
        findsOneWidget,
      );
      expect(find.text('Measurement profile'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), '175');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Measurement profile'), findsNothing);
      expect(result?.heightCm, 175);
      expect(result?.ageYears, 35);
      expect(result?.sex, 'male');
      expect(result?.valid, isTrue);
    });

    testWidgets('profile cancel returns null', (tester) async {
      UserProfile? result;
      await tester.pumpWidget(
        _launcher(
          label: 'open-profile',
          platform: TargetPlatform.android,
          onPressed: (context) async {
            result = await showProfileDialog(context);
          },
        ),
      );

      await tester.tap(find.text('open-profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Measurement profile'), findsNothing);
      expect(result, isNull);
    });

    testWidgets('manual weight validates and returns one decimal input',
        (tester) async {
      double? result;
      await tester.pumpWidget(
        _launcher(
          label: 'open-weight',
          platform: TargetPlatform.android,
          onPressed: (context) async {
            result = await showManualWeightDialog(context);
          },
        ),
      );

      await tester.tap(find.text('open-weight'));
      await tester.pumpAndSettle();
      expect(find.text('Add weight'), findsOneWidget);
      expect(
        find.textContaining('Body composition estimates need a scale reading'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextFormField), '0');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        find.text('Weight must be between 1 and 350 kg.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextFormField), '72,4');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Add weight'), findsNothing);
      expect(result, 72.4);
    });
  });

  group('Cupertino dialogs', () {
    testWidgets('iOS profile sheet shows validator errors and saves',
        (tester) async {
      UserProfile? result;
      await tester.pumpWidget(
        _launcher(
          label: 'open-profile',
          platform: TargetPlatform.iOS,
          onPressed: (context) async {
            result = await showProfileDialog(context);
          },
        ),
      );

      await tester.tap(find.text('open-profile'));
      await tester.pumpAndSettle();
      expect(find.text('Measurement profile'), findsOneWidget);
      expect(find.byType(CupertinoTextFormFieldRow), findsNWidgets(2));

      final fields = find.byType(CupertinoTextField);
      await tester.enterText(fields.at(0), '90');
      await tester.enterText(fields.at(1), '35');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Height must be between 100 and 250 cm.'),
        findsOneWidget,
      );
      expect(find.text('Measurement profile'), findsOneWidget);

      await tester.enterText(fields.at(0), '175');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Measurement profile'), findsNothing);
      expect(result?.heightCm, 175);
      expect(result?.ageYears, 35);
    });

    testWidgets('iOS manual weight sheet validates and saves', (tester) async {
      double? result;
      await tester.pumpWidget(
        _launcher(
          label: 'open-weight',
          platform: TargetPlatform.iOS,
          onPressed: (context) async {
            result = await showManualWeightDialog(context);
          },
        ),
      );

      await tester.tap(find.text('open-weight'));
      await tester.pumpAndSettle();
      expect(find.text('Add weight'), findsOneWidget);

      final field = find.byType(CupertinoTextField);
      await tester.enterText(field, '400');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        find.text('Weight must be between 1 and 350 kg.'),
        findsOneWidget,
      );

      await tester.enterText(field, '72.4');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Add weight'), findsNothing);
      expect(result, 72.4);
    });
  });
}

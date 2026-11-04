import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

import 'models/measurement.dart';
import 'models/user_profile.dart';
import 'services/bluetooth_permissions.dart';
import 'services/measurement_store.dart';
import 'services/scale_ble.dart';
import 'ui/dashboard_view.dart';
import 'ui/body_tokens.dart';

void main() => runApp(const BodyCompositionApp());

class BodyCompositionApp extends StatelessWidget {
  const BodyCompositionApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Body Composition',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: ThemeData(
            useMaterial3: true,
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xFF356DDA)),
            scaffoldBackgroundColor: const Color(0xFFF5F7FC)),
        builder: (context, child) => AdaptiveToolbarHost(child: child!),
        home: const Dashboard(),
      );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final store = MeasurementStore();
  final profileStore = UserProfileStore();
  final ble = ScaleBle();
  final bluetoothPermissions = BluetoothPermissions();
  List<Measurement> history = [];
  UserProfile? profile;
  StreamSubscription<Measurement>? subscription;
  bool scanning = false;
  String? error;
  String? success;

  @override
  void initState() {
    super.initState();
    _reload();
    profileStore.load().then((value) {
      if (mounted) setState(() => profile = value);
    });
    subscription = ble.measurements.listen((m) async {
      await store.save(m);
      await ble.disconnect();
      await _reload();
      if (mounted) setState(() {
        scanning = false;
        error = null;
        success = '${m.weightKg.toStringAsFixed(1)} kg recorded successfully.';
      });
    });
  }

  Future<void> _reload() async {
    final items = await store.load();
    if (mounted) setState(() => history = items);
  }

  bool get _isCupertino =>
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _editProfile() async {
    final height = TextEditingController(text: profile?.heightCm.toStringAsFixed(0) ?? '');
    final age = TextEditingController(text: profile?.ageYears.toString() ?? '');
    var sex = profile?.sex ?? 'male';

    final result = await (_isCupertino ? showCupertinoSheet<UserProfile> : showDialog<UserProfile>)(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) {
          void save() {
            final value = UserProfile(
              heightCm: double.tryParse(height.text.replaceAll(',', '.')) ?? 0,
              ageYears: int.tryParse(age.text) ?? 0,
              sex: sex,
            );
            if (value.valid) {
              Navigator.of(dialogContext).pop(value);
            }
          }

          if (_isCupertino) {
            return CupertinoPageScaffold(
              navigationBar: const CupertinoNavigationBar(middle: Text('Measurement profile')),
              child: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
                const SizedBox(height: 14),
                CupertinoTextField(
                  controller: height,
                  placeholder: 'Height (cm)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: CupertinoColors.label),
                  padding: const EdgeInsets.all(12),
                ),
                const SizedBox(height: 10),
                CupertinoTextField(
                  controller: age,
                  placeholder: 'Age (years)',
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: CupertinoColors.label),
                  padding: const EdgeInsets.all(12),
                ),
                const SizedBox(height: 10),
                CupertinoSlidingSegmentedControl<String>(
                  groupValue: sex,
                  children: const {
                    'male': Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Male')),
                    'female': Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Female')),
                  },
                  onValueChanged: (value) {
                    if (value != null) updateDialog(() => sex = value);
                  },
                ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: CupertinoButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel'))),
                Expanded(child: CupertinoButton.filled(onPressed: save, child: const Text('Save'))),
              ]),
              ])),
            );
          }

          return AlertDialog(
            backgroundColor: BodyTokens.surface,
            surfaceTintColor: Colors.transparent,
            title: const Text('Measurement profile', style: TextStyle(color: Color(0xFF111B3A))),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: height,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Height (cm)'),
              ),
              TextField(
                controller: age,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age (years)'),
              ),
              DropdownButtonFormField<String>(
                value: sex,
                decoration: const InputDecoration(labelText: 'Sex for estimation formulas'),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                ],
                onChanged: (value) {
                  if (value != null) updateDialog(() => sex = value);
                },
              ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
              FilledButton(onPressed: save, child: const Text('Save')),
            ],
          );
        },
      ),
    );

    height.dispose();
    age.dispose();
    if (result == null) return;
    await profileStore.save(result);
    if (mounted) setState(() => profile = result);
  }

  Future<void> _scan() async {
    if (profile == null) {
      await _editProfile();
      if (profile == null) return;
    }
    setState(() { error = null; success = null; });
    try {
      final permission = await bluetoothPermissions.request();
      if (permission != BluetoothPermissionResult.granted) {
        if (!mounted) return;
        setState(() => error =
            permission == BluetoothPermissionResult.permanentlyDenied
                ? 'Bluetooth access is disabled. Enable it in system settings.'
                : 'Bluetooth permission is required to connect to your scale.');
        if (permission == BluetoothPermissionResult.permanentlyDenied &&
            mounted) {
          if (_isCupertino) {
            final open = await showCupertinoModalPopup<bool>(
              context: context,
              builder: (popupContext) => CupertinoActionSheet(
                title: const Text('Bluetooth permission needed'),
                message: const Text('Enable Bluetooth access in Settings and try again.'),
                actions: [CupertinoActionSheetAction(
                  onPressed: () => Navigator.of(popupContext).pop(true),
                  child: const Text('Open settings'),
                )],
                cancelButton: CupertinoActionSheetAction(
                  onPressed: () => Navigator.of(popupContext).pop(false),
                  child: const Text('Not now'),
                ),
              ),
            );
            if (open == true) await bluetoothPermissions.openSettings();
          } else {
            final open = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Bluetooth permission needed'),
                content: const Text('Enable Bluetooth access in Settings and try again.'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Not now')),
                  FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Open settings')),
                ],
              ),
            );
            if (open == true) await bluetoothPermissions.openSettings();
          }
        }
        return;
      }
      if (!mounted) return;
      setState(() => scanning = true);
      await ble.scanAndConnect(profile: profile!);
      // Remain in measuring state until a stable measurement arrives or user cancels.
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          scanning = false;
        });
      }
      await ble.disconnect();
    }
  }

  Future<void> _cancel() async {
    await ble.disconnect();
    if (mounted) setState(() => scanning = false);
  }

  Future<void> _manual() async {
    if (profile == null) {
      await _editProfile();
      if (profile == null) return;
    }
    final controller = TextEditingController();
    final result = await (_isCupertino ? showCupertinoSheet<double> : showDialog<double>)(
      context: context,
      builder: (dialogContext) {
        void save() => Navigator.of(dialogContext).pop(
          double.tryParse(controller.text.replaceAll(',', '.')),
        );
        return _isCupertino
            ? CupertinoPageScaffold(
                navigationBar: const CupertinoNavigationBar(middle: Text('Add weight')),
                child: SafeArea(child: ListView(children: [Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: CupertinoTextField(
                    controller: controller,
                    placeholder: 'Weight (kg)',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: CupertinoColors.label),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(child: CupertinoButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel'))),
                  Expanded(child: CupertinoButton.filled(onPressed: save, child: const Text('Save'))),
                ]),
                ])),
              )
            : AlertDialog(
                backgroundColor: const Color(0xFFF9FAFF),
                surfaceTintColor: Colors.transparent,
                title: const Text('Add weight'),
                content: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(onPressed: save, child: const Text('Save')),
                ],
              );
      },
    );
    controller.dispose();
    if (result == null || result <= 0 || result > 350) return;
    final meters = profile!.heightCm / 100;
    await store.save(Measurement(
        timestamp: DateTime.now(),
        weightKg: result,
        bmi: result / (meters * meters)));
    await _reload();
    if (mounted) setState(() {
      error = null;
      success = '${result.toStringAsFixed(1)} kg added manually.';
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    unawaited(ble.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DashboardView(
        history: history,
        profile: profile,
        scanning: scanning,
        error: error,
        success: success,
        onMeasure: scanning ? _cancel : _scan,
        onManual: _manual,
        onProfile: _editProfile,
      );
}

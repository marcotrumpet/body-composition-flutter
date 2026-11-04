import 'dart:async';

import 'package:flutter/material.dart';

import 'models/measurement.dart';
import 'models/user_profile.dart';
import 'services/bluetooth_permissions.dart';
import 'services/measurement_store.dart';
import 'services/scale_ble.dart';
import 'ui/dashboard_view.dart';

void main() => runApp(const BodyCompositionApp());

class BodyCompositionApp extends StatelessWidget {
  const BodyCompositionApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Body Composition',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            useMaterial3: true,
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xFF356DDA)),
            scaffoldBackgroundColor: const Color(0xFFF5F7FC)),
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
      if (mounted) setState(() => scanning = false);
    });
  }

  Future<void> _reload() async {
    final items = await store.load();
    if (mounted) setState(() => history = items);
  }

  Future<void> _editProfile() async {
    final height =
        TextEditingController(text: profile?.heightCm.toStringAsFixed(0) ?? '');
    final age = TextEditingController(text: profile?.ageYears.toString() ?? '');
    var sex = profile?.sex ?? 'male';
    final result = await showDialog<UserProfile>(
        context: context,
        builder: (context) => StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                title: const Text('Measurement profile'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: height,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Height (cm)')),
                  TextField(
                      controller: age,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Age (years)')),
                  DropdownButtonFormField<String>(
                      initialValue: sex,
                      decoration: const InputDecoration(
                          labelText: 'Sex for estimation formulas'),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(value: 'female', child: Text('Female'))
                      ],
                      onChanged: (value) {
                        if (value != null) setDialogState(() => sex = value);
                      }),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () {
                        final value = UserProfile(
                            heightCm: double.tryParse(height.text) ?? 0,
                            ageYears: int.tryParse(age.text) ?? 0,
                            sex: sex);
                        if (value.valid) Navigator.pop(context, value);
                      },
                      child: const Text('Save')),
                ],
              ),
            ));
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
    setState(() => error = null);
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
          await showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                    title: const Text('Bluetooth permission needed'),
                    content: const Text(
                        'Enable Bluetooth access for this app in system settings, then try again.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Not now')),
                      FilledButton(
                          onPressed: () {
                            Navigator.pop(context);
                            bluetoothPermissions.openSettings();
                          },
                          child: const Text('Open settings')),
                    ],
                  ));
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
    final result = await showDialog<double>(
        // ignore: use_build_context_synchronously
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Add weight'),
              content: TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Weight (kg)')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context,
                        double.tryParse(controller.text.replaceAll(',', '.'))),
                    child: const Text('Save')),
              ],
            ));
    controller.dispose();
    if (result == null || result <= 0 || result > 350) return;
    final meters = profile!.heightCm / 100;
    await store.save(Measurement(
        timestamp: DateTime.now(),
        weightKg: result,
        bmi: result / (meters * meters)));
    await _reload();
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
        onMeasure: scanning ? _cancel : _scan,
        onManual: _manual,
        onProfile: _editProfile,
      );
}

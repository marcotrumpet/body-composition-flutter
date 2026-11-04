import 'dart:async';
import 'package:flutter/material.dart';
import 'models/measurement.dart';
import 'models/user_profile.dart';
import 'services/measurement_store.dart';
import 'services/scale_ble.dart';

void main() => runApp(const BodyCompositionApp());

class BodyCompositionApp extends StatelessWidget {
  const BodyCompositionApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Body Composition',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF356DDA)),
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
  List<Measurement> history = [];
  UserProfile? profile;
  StreamSubscription<Measurement>? subscription;
  bool scanning = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _reload();
    profileStore.load().then((value) { if (mounted) setState(() => profile = value); });
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
    final height = TextEditingController(text: profile?.heightCm.toStringAsFixed(0) ?? '');
    final age = TextEditingController(text: profile?.ageYears.toString() ?? '');
    var sex = profile?.sex ?? 'male';
    final result = await showDialog<UserProfile>(context: context, builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Measurement profile'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: height, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Height (cm)')),
          TextField(controller: age, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Age (years)')),
          DropdownButtonFormField<String>(initialValue: sex, decoration: const InputDecoration(labelText: 'Sex for estimation formulas'),
            items: const [DropdownMenuItem(value: 'male', child: Text('Male')), DropdownMenuItem(value: 'female', child: Text('Female'))],
            onChanged: (value) { if (value != null) setDialogState(() => sex = value); }),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            final value = UserProfile(heightCm: double.tryParse(height.text) ?? 0,
                ageYears: int.tryParse(age.text) ?? 0, sex: sex);
            if (value.valid) Navigator.pop(context, value);
          }, child: const Text('Save')),
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
    if (profile == null) { await _editProfile(); if (profile == null) return; }
    setState(() { scanning = true; error = null; });
    try {
      await ble.scanAndConnect(profile: profile!);
      // Remain in measuring state until a stable measurement arrives or user cancels.
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); scanning = false; });
      await ble.disconnect();
    }
  }
  Future<void> _cancel() async {
    await ble.disconnect();
    if (mounted) setState(() => scanning = false);
  }
  Future<void> _manual() async {
    if (profile == null) { await _editProfile(); if (profile == null) return; }
    final controller = TextEditingController();
    final result = await showDialog<double>(context: context, builder: (context) => AlertDialog(
      title: const Text('Add weight'),
      content: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Weight (kg)')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, double.tryParse(controller.text.replaceAll(',', '.'))), child: const Text('Save')),
      ],
    ));
    controller.dispose();
    if (result == null || result <= 0 || result > 350) return;
    final meters = profile!.heightCm / 100;
    await store.save(Measurement(timestamp: DateTime.now(), weightKg: result, bmi: result / (meters * meters)));
    await _reload();
  }
  @override
  void dispose() {
    subscription?.cancel();
    unawaited(ble.dispose());
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final latest = history.isEmpty ? null : history.first;
    return Scaffold(
      appBar: AppBar(title: const Text('Body Composition'), backgroundColor: Colors.transparent,
        actions: [IconButton(onPressed: _editProfile, tooltip: 'Profile', icon: const Icon(Icons.person_outline))]),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Your health, at a glance', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('LATEST WEIGHT', style: TextStyle(letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Text(latest == null ? '— kg' : '${latest.weightKg.toStringAsFixed(2)} kg',
              style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold)),
          if (latest?.bmi != null) Text('BMI ${latest!.bmi!.toStringAsFixed(1)}'),
          if (latest?.impedance != null) Text('Impedance ${latest!.impedance} Ω'),
          if (latest?.bodyFatPercent != null) Text('Estimated body fat ${latest!.bodyFatPercent!.toStringAsFixed(1)}%'),
        ]))),
        const SizedBox(height: 12),
        Card(child: ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(profile == null ? 'Set up your profile' : '${profile!.heightCm.toStringAsFixed(0)} cm · ${profile!.ageYears} years'),
          subtitle: const Text('Used for BMI and body composition estimates'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _editProfile,
        )),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: scanning ? _cancel : _scan,
          icon: Icon(scanning ? Icons.stop_circle_outlined : Icons.bluetooth_searching),
          label: Text(scanning ? 'Stop measuring' : 'Connect Xiaomi scale')),
        OutlinedButton.icon(onPressed: _manual, icon: const Icon(Icons.add), label: const Text('Add manually')),
        if (error != null) Padding(padding: const EdgeInsets.all(8),
          child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 24),
        Text('History', style: Theme.of(context).textTheme.titleLarge),
        if (history.isEmpty) const Padding(padding: EdgeInsets.all(24),
          child: Text('No measurements yet. Connect your scale or add one manually.')),
        ...history.map((m) => Card(child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.monitor_weight_outlined)),
          title: Text('${m.weightKg.toStringAsFixed(2)} kg'),
          subtitle: Text('${m.timestamp.day}/${m.timestamp.month}/${m.timestamp.year} · ${m.timestamp.hour.toString().padLeft(2, '0')}:${m.timestamp.minute.toString().padLeft(2, '0')}'),
          trailing: m.bmi == null ? null : Text('BMI ${m.bmi!.toStringAsFixed(1)}'),
        ))),
      ])),
    );
  }
}

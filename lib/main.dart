import 'dart:async';
import 'package:flutter/material.dart';
import 'models/measurement.dart';
import 'services/measurement_store.dart';
import 'services/scale_ble.dart';

void main() => runApp(const BodyCompositionApp());

class BodyCompositionApp extends StatelessWidget {
  const BodyCompositionApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Body Composition',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF356DDA)), scaffoldBackgroundColor: const Color(0xFFF5F7FC)),
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
  final ble = ScaleBle();
  List<Measurement> history = [];
  StreamSubscription<Measurement>? subscription;
  bool scanning = false;
  String? error;
  double heightCm = 175;

  @override
  void initState() {
    super.initState();
    _reload();
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
  Future<void> _scan() async {
    setState(() { scanning = true; error = null; });
    try {
      await ble.scanAndConnect(heightCm: heightCm);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
      await ble.disconnect();
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }
  Future<void> _manual() async {
    final controller = TextEditingController();
    final result = await showDialog<double>(context: context, builder: (context) => AlertDialog(
      title: const Text('Add weight'),
      content: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Weight (kg)')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, double.tryParse(controller.text.replaceAll(',', '.'))), child: const Text('Save')),
      ],
    ));
    controller.dispose();
    if (result == null || result <= 0 || result > 350) return;
    final meters = heightCm / 100;
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
      appBar: AppBar(title: const Text('Body Composition'), backgroundColor: Colors.transparent),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Your health, at a glance', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('LATEST WEIGHT', style: TextStyle(letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Text(latest == null ? '— kg' : '${latest.weightKg.toStringAsFixed(2)} kg', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold)),
          if (latest?.bmi != null) Text('BMI ${latest!.bmi!.toStringAsFixed(1)}'),
          if (latest?.impedance != null) Text('Impedance ${latest!.impedance} Ω'),
        ]))),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          const Expanded(child: Text('Height (cm)')),
          DropdownButton<double>(value: heightCm, items: [160.0, 165, 170, 175, 180, 185, 190, 195, 200].map((v) => DropdownMenuItem(value: v, child: Text(v.toStringAsFixed(0)))).toList(), onChanged: (v) { if (v != null) setState(() => heightCm = v); }),
        ]))),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: scanning ? null : _scan, icon: const Icon(Icons.bluetooth_searching), label: Text(scanning ? 'Scanning…' : 'Connect Xiaomi scale')),
        OutlinedButton.icon(onPressed: _manual, icon: const Icon(Icons.add), label: const Text('Add manually')),
        if (error != null) Padding(padding: const EdgeInsets.all(8), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 24),
        Text('History', style: Theme.of(context).textTheme.titleLarge),
        if (history.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No measurements yet. Connect your scale or add one manually.')),
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

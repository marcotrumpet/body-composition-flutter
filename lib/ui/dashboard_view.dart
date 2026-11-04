import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../models/measurement.dart';
import '../models/user_profile.dart';
import 'body_tokens.dart';

const _ink = BodyTokens.ink;
const _blue = BodyTokens.accent;
const _purple = BodyTokens.secondaryAccent;

class DashboardView extends StatefulWidget {
  const DashboardView({super.key, required this.history, required this.profile,
    required this.scanning, required this.error, required this.success, required this.onMeasure,
    required this.onManual, required this.onProfile});
  final List<Measurement> history;
  final UserProfile? profile;
  final bool scanning;
  final String? error;
  final String? success;
  final VoidCallback onMeasure;
  final VoidCallback onManual;
  final VoidCallback onProfile;
  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      backgroundColor: const Color(0xFFF1F4FF),
      appBar: AdaptiveAppBar(
        title: tab == 0 ? 'Body Composition' : tab == 1 ? 'Trends' : 'Profile',
        useNativeToolbar: true,
        actions: [
          AdaptiveAppBarAction(
            iosSymbol: 'slider.horizontal.3',
            icon: Icons.tune_rounded,
            label: 'Edit profile',
            onPressed: widget.onProfile,
          ),
        ],
      ),
      bottomNavigationBar: AdaptiveBottomNavigationBar(
        useNativeBottomBar: true,
        items: [
          AdaptiveNavigationDestination(icon: 'house.fill', label: 'Home'),
          AdaptiveNavigationDestination(icon: 'chart.xyaxis.line', label: 'Trends'),
          AdaptiveNavigationDestination(icon: 'person.crop.circle', label: 'Profile'),
        ],
        selectedIndex: tab,
        onTap: (index) => setState(() => tab = index),
      ),
      body: Stack(children: [
        const Positioned.fill(child: _Atmosphere()),
        SafeArea(bottom: false, child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(
            key: ValueKey(tab),
            child: tab == 0 ? _home() : tab == 1 ? _history() : _profile(),
          ),
        )),
      ]),
    );
  }

  Widget _home() {
    final latest = widget.history.isEmpty ? null : widget.history.first;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 10, 20, 120), children: [
      _Glass(padding: const EdgeInsets.all(26), radius: 32, child: Column(children: [
        const Text('LATEST WEIGHT', style: TextStyle(color: _blue, fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 11)),
        const SizedBox(height: 14),
        Container(width: 210, height: 210, alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: const RadialGradient(colors: [Color(0xFFFFFFFF), Color(0xFFDBE7FF), Color(0xFFACBDFD), Color(0xFF9A82E9)]),
            boxShadow: [BoxShadow(color: _blue.withValues(alpha: .25), blurRadius: 48, spreadRadius: 3)],
            border: Border.all(color: Colors.white.withValues(alpha: .85), width: 3)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(latest == null ? '—' : latest.weightKg.toStringAsFixed(1),
              style: const TextStyle(fontSize: 55, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -2)),
            const Text('kg', style: TextStyle(color: _ink, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(latest?.bmi == null ? 'Ready to measure' : 'BMI ${latest!.bmi!.toStringAsFixed(1)}',
              style: TextStyle(color: _ink.withValues(alpha: .65), fontSize: 12)),
          ])),
        const SizedBox(height: 22),
        Text(latest == null ? 'Connect your scale to get started' : 'Your latest measurement',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
      ])),
      const SizedBox(height: 22),
      const Text('BODY METRICS', style: TextStyle(color: _ink, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _metric(Icons.water_drop_outlined, 'Body fat', latest?.bodyFatPercent, '%', const Color(0xFF885CF6))),
        const SizedBox(width: 12),
        Expanded(child: _metric(Icons.bolt_outlined, 'Impedance', latest?.impedance?.toDouble(), 'Ω', const Color(0xFF00A8B5))),
      ]),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: AdaptiveButton(
        onPressed: widget.onMeasure,
        label: widget.scanning ? 'Stop measuring' : 'Measure on scale',
        style: AdaptiveButtonStyle.filled,
        size: AdaptiveButtonSize.large,
      )),
      const SizedBox(height: 8),
      Center(child: AdaptiveButton(
        onPressed: widget.onManual,
        label: 'Add measurement manually',
        style: AdaptiveButtonStyle.tinted,
      )),
      if (widget.scanning) _status(
        Icons.bluetooth_searching_rounded,
        'Connecting to your scale',
        'Step onto the scale and wait for a stable reading. Tap Stop measuring to cancel.',
        const Color(0xFF3659B9),
      ),
      if (widget.error != null) _status(
        Icons.info_outline_rounded,
        'Measurement unavailable',
        widget.error!,
        const Color(0xFFAD3451),
      ),
      if (widget.success != null && !widget.scanning && widget.error == null)
        _status(
          Icons.check_circle_outline_rounded,
          'Measurement saved',
          widget.success!,
          const Color(0xFF177B70),
        ),
    ]);
  }

  Widget _status(IconData icon, String title, String description, Color accent) =>
    Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .94),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: .24)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: accent, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink)),
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(fontSize: 13, color: _ink, height: 1.4)),
            ])),
          ]),
        ),
      ),
    );

  Widget _metric(IconData icon, String title, double? value, String suffix, Color color) =>
    _Glass(radius: 24, padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 26),
      const SizedBox(height: 14),
      Text(value == null ? '—' : '${value.toStringAsFixed(1)} $suffix',
        style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w800)),
      Text(title, style: TextStyle(color: _ink.withValues(alpha: .6), fontSize: 12)),
    ]));

  Widget _history() {
    final measurements = widget.history.reversed.toList();
    return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 120), children: [
      _Glass(radius: 30, padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Weight evolution', style: TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('All recorded measurements', style: TextStyle(color: Color(0xFF7A829C), fontSize: 12)),
        const SizedBox(height: 26),
        SizedBox(height: 210, child: measurements.length < 2
          ? const Center(child: Text('Add two measurements to see your trend'))
          : LineChart(LineChartData(
              minY: measurements.map((m) => m.weightKg).reduce((a, b) => a < b ? a : b) - 2,
              maxY: measurements.map((m) => m.weightKg).reduce((a, b) => a > b ? a : b) + 2,
              gridData: FlGridData(show: true, drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: _blue.withValues(alpha: .1), strokeWidth: 1)),
              titlesData: const FlTitlesData(topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
              borderData: FlBorderData(show: false),
              lineBarsData: [LineChartBarData(
                spots: [for (var i = 0; i < measurements.length; i++) FlSpot(i.toDouble(), measurements[i].weightKg)],
                isCurved: true, barWidth: 3, color: _purple,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(show: true, color: _purple.withValues(alpha: .12)),
              )]))),
      ])),
      const SizedBox(height: 24),
      const Text('RECENT READINGS', style: TextStyle(color: _ink, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
      const SizedBox(height: 12),
      if (widget.history.isEmpty)
        _status(Icons.show_chart_rounded, 'No readings yet',
          'Take a measurement or add your weight manually to start tracking your trend.',
          const Color(0xFF3659B9)),
      ...widget.history.map((m) => Padding(padding: const EdgeInsets.only(bottom: 10),
        child: _Glass(radius: 20, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            const CircleAvatar(backgroundColor: Color(0xFFE8EAFF), child: Icon(Icons.monitor_weight_outlined, color: _blue)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${m.weightKg.toStringAsFixed(2)} kg', style: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w800)),
              Text('${m.timestamp.day}/${m.timestamp.month}/${m.timestamp.year} · ${m.timestamp.hour.toString().padLeft(2, '0')}:${m.timestamp.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Color(0xFF7A829C), fontSize: 12)),
            ])),
            if (m.bmi != null) Text('BMI ${m.bmi!.toStringAsFixed(1)}',
              style: const TextStyle(color: _blue, fontWeight: FontWeight.w700)),
          ])))),
    ]);
  }

  Widget _profile() => ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 120), children: [
    _Glass(radius: 30, padding: const EdgeInsets.all(24), child: Column(children: [
      const CircleAvatar(radius: 38, backgroundColor: Color(0xFFE2E7FF),
        child: Icon(Icons.person_rounded, color: _blue, size: 38)),
      const SizedBox(height: 14),
      Text(widget.profile == null ? 'Set up your profile' : 'Your measurement profile',
        style: const TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      Text(widget.profile == null ? 'Height, age and sex are needed for composition estimates'
        : '${widget.profile!.heightCm.toStringAsFixed(0)} cm · ${widget.profile!.ageYears} years · ${widget.profile!.sex}',
        textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7A829C))),
      const SizedBox(height: 22),
      AdaptiveButton(onPressed: widget.onProfile, label: 'Edit profile'),
    ])),
    const SizedBox(height: 16),
    const _Glass(radius: 22, padding: EdgeInsets.all(18),
      child: Text('Body composition values are estimates derived from impedance. They are not medical diagnoses.',
        style: TextStyle(color: _ink, height: 1.5))),
  ]);
}

class _Glass extends StatelessWidget {
  const _Glass({required this.child, required this.padding, this.radius = 24});
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withValues(alpha: .9)),
          boxShadow: [BoxShadow(color: _blue.withValues(alpha: .07), blurRadius: 24, offset: const Offset(0, 8))]),
        child: child)),
  );
}

class _Atmosphere extends StatelessWidget {
  const _Atmosphere();
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFFF0F6FF), Color(0xFFE9E7FF), Color(0xFFF7F7FE)])),
    child: Stack(children: [
      Positioned(top: -110, right: -90, child: _orb(280, const Color(0xFFB2BCFF))),
      Positioned(bottom: 80, left: -140, child: _orb(320, const Color(0xFFB8E5FC))),
    ]),
  );
  Widget _orb(double size, Color color) => Container(width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
      BoxShadow(color: color.withValues(alpha: .5), blurRadius: 100, spreadRadius: 35)]));
}

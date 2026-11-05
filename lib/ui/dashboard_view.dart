import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/garmin_account.dart';
import '../models/measurement.dart';
import '../models/user_profile.dart';
import '../services/scale_ble.dart';
import 'body_format.dart';
import 'body_tokens.dart';
import 'profile_view.dart';
import 'trends_view.dart';
import 'widgets/body_surface.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({
    super.key,
    required this.history,
    required this.profile,
    required this.loadingHistory,
    required this.loadingProfile,
    required this.phase,
    required this.notice,
    required this.onMeasure,
    required this.onManual,
    required this.onProfile,
    this.garminAccount,
    this.garminLoading = false,
    this.garminBusy = false,
    this.garminSyncingReading = false,
    this.garminPendingReadings = 0,
    this.garminSyncCompleted,
    this.garminSyncTotal,
    this.onGarminConnect,
    this.onGarminSync,
    this.onGarminDisconnect,
  });

  final List<Measurement> history;
  final UserProfile? profile;
  final bool loadingHistory;
  final bool loadingProfile;
  final ScalePhase phase;
  final DashboardNotice? notice;
  final VoidCallback onMeasure;
  final VoidCallback onManual;
  final VoidCallback onProfile;
  final GarminAccount? garminAccount;
  final bool garminLoading;
  final bool garminBusy;

  /// True while a new scale reading is being uploaded, the last measuring step.
  final bool garminSyncingReading;
  final int garminPendingReadings;
  final int? garminSyncCompleted;
  final int? garminSyncTotal;
  final VoidCallback? onGarminConnect;
  final VoidCallback? onGarminSync;
  final VoidCallback? onGarminDisconnect;

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int tab = 0;

  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  bool get _scanning => widget.phase != ScalePhase.idle;

  @override
  Widget build(BuildContext context) {
    final colors = BodyColors.of(context);
    final isIOS = _isIOS;
    final bottomClearance = isIOS ? 120.0 : 96.0;

    final destinations = isIOS
        ? const [
            AdaptiveNavigationDestination(icon: 'house.fill', label: 'Home'),
            AdaptiveNavigationDestination(
              icon: 'chart.xyaxis.line',
              label: 'Trends',
            ),
            AdaptiveNavigationDestination(
              icon: 'person.crop.circle',
              label: 'Profile',
            ),
          ]
        : const [
            AdaptiveNavigationDestination(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'Home',
            ),
            AdaptiveNavigationDestination(
              icon: Icons.show_chart_rounded,
              selectedIcon: Icons.show_chart_rounded,
              label: 'Trends',
            ),
            AdaptiveNavigationDestination(
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
              label: 'Profile',
            ),
          ];

    final cupertinoTabBar = isIOS
        ? CupertinoTabBar(
            currentIndex: tab,
            onTap: (index) => setState(() => tab = index),
            activeColor: colors.accent,
            inactiveColor: colors.secondaryInk,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.house),
                activeIcon: Icon(CupertinoIcons.house_fill),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.chart_bar_alt_fill),
                label: 'Trends',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.person_crop_circle),
                label: 'Profile',
              ),
            ],
          )
        : null;

    return AdaptiveScaffold(
      backgroundColor: colors.canvas,
      // Keep the native tab bar at full size while the user scrolls. The
      // default automatic behavior shrinks it on iOS 26.
      minimizeBehavior: TabBarMinimizeBehavior.never,
      appBar: AdaptiveAppBar(
        title: switch (tab) {
          0 => 'Body Composition',
          1 => 'Trends',
          _ => 'Profile',
        },
        useNativeToolbar: true,
        actions: tab == 2
            ? const []
            : [
                AdaptiveAppBarAction(
                  iosSymbol: 'person.crop.circle',
                  iconWidget: Icon(
                    isIOS
                        ? CupertinoIcons.person_crop_circle
                        : Icons.person_outline_rounded,
                  ),
                  label: 'Edit profile',
                  onPressed: widget.onProfile,
                ),
              ],
      ),
      bottomNavigationBar: AdaptiveBottomNavigationBar(
        useNativeBottomBar: true,
        items: destinations,
        selectedIndex: tab,
        onTap: (index) => setState(() => tab = index),
        selectedItemColor: colors.accent,
        unselectedItemColor: colors.secondaryInk,
        cupertinoTabBar: cupertinoTabBar,
      ),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: tab,
          children: [
            TickerMode(
              enabled: tab == 0,
              child: _HomeTab(
                history: widget.history,
                profile: widget.profile,
                loadingHistory: widget.loadingHistory,
                loadingProfile: widget.loadingProfile,
                phase: widget.phase,
                notice: widget.notice,
                onMeasure: widget.onMeasure,
                onManual: widget.onManual,
                onProfile: widget.onProfile,
                garminConnected: widget.garminAccount != null,
                garminSyncingReading: widget.garminSyncingReading,
                bottomClearance: bottomClearance,
              ),
            ),
            TickerMode(
              enabled: tab == 1,
              child: TrendsView(
                history: widget.history,
                loadingHistory: widget.loadingHistory,
                notice: widget.notice,
                onAddMeasurement: _scanning ? null : widget.onManual,
                bottomClearance: bottomClearance,
              ),
            ),
            TickerMode(
              enabled: tab == 2,
              child: ProfileView(
                profile: widget.profile,
                loadingProfile: widget.loadingProfile,
                notice: widget.notice,
                onProfile: widget.onProfile,
                bottomClearance: bottomClearance,
                garminAccount: widget.garminAccount,
                garminLoading: widget.garminLoading,
                garminBusy: widget.garminBusy,
                garminPendingReadings: widget.garminPendingReadings,
                garminSyncCompleted: widget.garminSyncCompleted,
                garminSyncTotal: widget.garminSyncTotal,
                onGarminConnect: widget.onGarminConnect,
                onGarminSync: widget.onGarminSync,
                onGarminDisconnect: widget.onGarminDisconnect,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.history,
    required this.profile,
    required this.loadingHistory,
    required this.loadingProfile,
    required this.phase,
    required this.notice,
    required this.onMeasure,
    required this.onManual,
    required this.onProfile,
    required this.garminConnected,
    required this.garminSyncingReading,
    required this.bottomClearance,
  });

  final List<Measurement> history;
  final UserProfile? profile;
  final bool loadingHistory;
  final bool loadingProfile;
  final ScalePhase phase;
  final DashboardNotice? notice;
  final VoidCallback onMeasure;
  final VoidCallback onManual;
  final VoidCallback onProfile;
  final bool garminConnected;
  final bool garminSyncingReading;
  final double bottomClearance;

  bool get _scanning => phase != ScalePhase.idle;
  Measurement? get _latest => history.isEmpty ? null : history.first;
  Measurement? get _previous => history.length > 1 ? history[1] : null;

  Measurement? get _latestEstimate {
    for (final measurement in history) {
      if (measurement.impedance != null) return measurement;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = BodyColors.of(context);
    final latest = _latest;
    final estimate = _latestEstimate;
    return BodyListView(
      storageKey: const PageStorageKey<String>('home'),
      bottom: bottomClearance,
      children: [
        _HeroCard(latest: latest, previous: _previous, loading: loadingHistory),
        const SizedBox(height: BodySpace.lg),
        SizedBox(
          width: double.infinity,
          child: AdaptiveButton(
            onPressed: onMeasure,
            label: _scanning ? 'Stop measuring' : 'Measure on scale',
            style: _scanning
                ? AdaptiveButtonStyle.gray
                : AdaptiveButtonStyle.filled,
            color: _scanning ? null : colors.accent,
            textColor: _scanning ? null : colors.onAccent,
            size: AdaptiveButtonSize.large,
            minSize: const Size(0, 52),
          ),
        ),
        const SizedBox(height: BodySpace.sm),
        SizedBox(
          width: double.infinity,
          child: AdaptiveButton(
            onPressed: onManual,
            enabled: !_scanning,
            label: 'Add weight manually',
            style: AdaptiveButtonStyle.plain,
            size: AdaptiveButtonSize.large,
            minSize: const Size(0, BodySpace.minimumTapTarget),
            // The iOS 26 native title-mode button collapses to a zero-width
            // platform view when minWidth is 0, leaving no hit area.
            useNative: false,
          ),
        ),
        NoticeSlot(notice: notice),
        if (_scanning || garminSyncingReading) ...[
          const SizedBox(height: BodySpace.lg),
          _ScanningCard(phase: phase, garminConnected: garminConnected),
        ],
        if (!loadingProfile && profile == null) ...[
          const SizedBox(height: BodySpace.lg),
          EmptyPanel(
            icon: Icons.person_outline_rounded,
            title: 'Add a profile for estimates',
            message:
                'Height, age and sex help interpret impedance. Weight readings still work without a profile.',
            actionLabel: 'Set up profile',
            onAction: onProfile,
          ),
        ],
        if (latest != null) ...[
          const SizedBox(height: BodySpace.xl),
          const SectionLabel('Body metrics'),
          const SizedBox(height: BodySpace.md),
          _MetricsSection(latest: latest, estimate: estimate, profile: profile),
        ] else if (!loadingHistory) ...[
          const SizedBox(height: BodySpace.lg),
          const EmptyPanel(
            icon: Icons.monitor_weight_outlined,
            title: 'Ready for your first reading',
            message:
                'Step on with bare feet, stand still, and keep your phone nearby. Weight, BMI and estimates will appear here.',
          ),
        ],
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.latest,
    required this.previous,
    required this.loading,
  });

  final Measurement? latest;
  final Measurement? previous;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = BodyColors.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final measurement = latest;

    if (loading) {
      return SurfaceCard(
        padding: const EdgeInsets.all(BodySpace.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel('Latest weight'),
            const SizedBox(height: BodySpace.md),
            Text(
              'Loading your readings…',
              style: BodyType.body.copyWith(color: colors.secondaryInk),
            ),
          ],
        ),
      );
    }

    if (measurement == null) {
      return SurfaceCard(
        padding: const EdgeInsets.all(BodySpace.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Latest weight'),
            const SizedBox(height: BodySpace.md),
            Text(
              'No readings yet',
              style: BodyType.title.copyWith(color: colors.ink),
            ),
            const SizedBox(height: BodySpace.xs),
            Text(
              'Take your first reading to see your weight and trend here.',
              style: BodyType.caption.copyWith(color: colors.secondaryInk),
            ),
          ],
        ),
      );
    }

    final bmi = measurement.bmi;
    final date = formatDateTime(context, measurement.timestamp);
    final delta = previous == null
        ? null
        : formatWeightDelta(measurement.weightKg, previous!.weightKg);
    final semantics = [
      'Latest weight ${spokenWeight(measurement.weightKg)}',
      if (bmi != null) 'BMI ${formatBmi(bmi)}',
      date,
      if (delta != null) delta,
    ].join('. ');

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Latest weight'),
        const SizedBox(height: BodySpace.md),
        AnimatedSwitcher(
          duration: reduceMotion ? Duration.zero : BodyMotion.medium,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: Row(
            key: ValueKey(measurement.timestamp),
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    formatWeight(measurement.weightKg),
                    style: BodyType.display.copyWith(color: colors.ink),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: BodySpace.sm,
                  bottom: BodySpace.sm,
                ),
                child: Text(
                  'kg',
                  style: BodyType.title.copyWith(color: colors.secondaryInk),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: BodySpace.sm),
        Text(
          [if (bmi != null) 'BMI ${formatBmi(bmi)}', date].join(' · '),
          style: BodyType.caption.copyWith(color: colors.secondaryInk),
        ),
        if (delta != null) ...[
          const SizedBox(height: BodySpace.xs),
          Text(
            delta,
            style: BodyType.caption.copyWith(color: colors.secondaryInk),
          ),
        ],
      ],
    );

    return Semantics(
      container: true,
      label: semantics,
      excludeSemantics: true,
      child: SurfaceCard(
        padding: const EdgeInsets.all(BodySpace.card),
        child: content,
      ),
    );
  }
}

class _MetricsSection extends StatelessWidget {
  const _MetricsSection({
    required this.latest,
    required this.estimate,
    required this.profile,
  });

  final Measurement latest;
  final Measurement? estimate;
  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final colors = BodyColors.of(context);
    final estimateReading = estimate;
    final metrics = estimateReading?.estimatesFor(profile);
    final older =
        estimateReading != null &&
        estimateReading.timestamp != latest.timestamp;
    final caption = older
        ? 'From ${formatDay(context, estimateReading.timestamp)}'
        : null;
    final bodyFatPercent =
        estimateReading?.bodyFatPercent ?? metrics?.fatPercent;
    final hasBodyFat = bodyFatPercent != null;
    final bodyFatCaption = hasBodyFat
        ? caption
        : profile == null
        ? 'Add a profile'
        : 'Not available';

    final bodyFat = MetricTile(
      icon: Icons.percent_rounded,
      label: 'Body fat',
      value: formatBodyFat(bodyFatPercent),
      badge: 'est.',
      caption: bodyFatCaption,
      iconColor: colors.bodyFat,
      semanticLabel: hasBodyFat
          ? 'Body fat estimate ${bodyFatPercent.toStringAsFixed(1)} percent'
          : 'Body fat estimate not available',
    );
    final impedance = MetricTile(
      icon: Icons.bolt_outlined,
      label: 'Impedance',
      value: formatImpedance(estimateReading?.impedance),
      caption: estimateReading == null ? 'Not available' : caption,
      iconColor: colors.impedance,
      semanticLabel: estimateReading?.impedance == null
          ? 'Impedance not available'
          : 'Impedance ${estimateReading!.impedance} ohms',
    );

    final tiles = <Widget>[
      bodyFat,
      if (metrics != null) ...[
        MetricTile(
          icon: Icons.fitness_center_rounded,
          label: 'Muscle mass',
          value: '${formatWeight(metrics.muscleMassKg)} kg',
          badge: 'est.',
          iconColor: colors.accentText,
          semanticLabel:
              'Muscle mass estimate ${metrics.muscleMassKg.toStringAsFixed(1)} kilograms',
        ),
        MetricTile(
          icon: Icons.water_drop_outlined,
          label: 'Body water',
          value: '${metrics.waterPercent.toStringAsFixed(1)}%',
          badge: 'est.',
          iconColor: colors.impedance,
          semanticLabel:
              'Body water estimate ${metrics.waterPercent.toStringAsFixed(1)} percent',
        ),
        MetricTile(
          icon: Icons.accessibility_new_rounded,
          label: 'Bone mass',
          value: '${formatWeight(metrics.boneMassKg)} kg',
          badge: 'est.',
          iconColor: colors.accentText,
          semanticLabel:
              'Bone mass estimate ${metrics.boneMassKg.toStringAsFixed(1)} kilograms',
        ),
        MetricTile(
          icon: Icons.favorite_border_rounded,
          label: 'Visceral fat',
          value: '${metrics.visceralFatRating.round()}',
          badge: 'est.',
          iconColor: colors.danger,
          semanticLabel:
              'Visceral fat estimate ${metrics.visceralFatRating.round()}',
        ),
        MetricTile(
          icon: Icons.hourglass_bottom_rounded,
          label: 'Metabolic age',
          value: '${metrics.metabolicAge.round()} yrs',
          badge: 'est.',
          iconColor: colors.success,
          semanticLabel:
              'Metabolic age estimate ${metrics.metabolicAge.round()} years',
        ),
      ],
      impedance,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final stack = constraints.maxWidth < 340 || scale > 1.3;
            if (stack) {
              return Column(
                children: [
                  for (var index = 0; index < tiles.length; index++) ...[
                    if (index > 0) const SizedBox(height: BodySpace.md),
                    tiles[index],
                  ],
                ],
              );
            }
            final width = (constraints.maxWidth - BodySpace.md) / 2;
            return Wrap(
              spacing: BodySpace.md,
              runSpacing: BodySpace.md,
              children: [
                for (final tile in tiles) SizedBox(width: width, child: tile),
              ],
            );
          },
        ),
        const SizedBox(height: BodySpace.md),
        Text(
          'Body composition values are estimates from impedance and your profile. They are not medical diagnoses.',
          style: BodyType.caption.copyWith(color: colors.secondaryInk),
        ),
        if (!hasBodyFat) ...[
          const SizedBox(height: BodySpace.sm),
          Text(
            profile == null
                ? 'Add your profile to estimate body fat from impedance.'
                : 'Body composition needs a steady impedance reading. Step on with bare feet and stand still.',
            style: BodyType.caption.copyWith(color: colors.secondaryInk),
          ),
        ],
      ],
    );
  }
}

/// Progress through a measurement. The scale session is finished once the
/// phase is back to idle, so a card that is still showing is on the Garmin step.
class _ScanningCard extends StatelessWidget {
  const _ScanningCard({required this.phase, required this.garminConnected});

  final ScalePhase phase;
  final bool garminConnected;

  @override
  Widget build(BuildContext context) {
    final colors = BodyColors.of(context);
    final labels = [
      'Looking',
      'Connecting',
      'Reading',
      if (garminConnected) 'Syncing',
    ];
    final step = switch (phase) {
      ScalePhase.discovering => 0,
      ScalePhase.connecting => 1,
      ScalePhase.waitingForReading => 2,
      ScalePhase.idle => 3,
    };
    final title = switch (phase) {
      ScalePhase.discovering => 'Looking for your scale',
      ScalePhase.connecting => 'Connecting to your scale',
      ScalePhase.waitingForReading => 'Step on the scale',
      ScalePhase.idle => 'Syncing with Garmin',
    };
    final message = switch (phase) {
      ScalePhase.discovering => 'Wake the scale and keep it near your phone.',
      ScalePhase.connecting => 'This only takes a moment.',
      ScalePhase.waitingForReading =>
        'Stand still with bare feet until the reading is saved.',
      ScalePhase.idle => 'Your reading is saved. You can keep using the app.',
    };

    return Semantics(
      container: true,
      liveRegion: true,
      child: SurfaceCard(
        padding: const EdgeInsets.all(BodySpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: BodyType.body.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: BodySpace.xs),
            Text(
              message,
              style: BodyType.caption.copyWith(color: colors.secondaryInk),
            ),
            const SizedBox(height: BodySpace.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < labels.length; index++)
                  Expanded(
                    child: _PhaseStep(
                      index: index,
                      total: labels.length,
                      step: step,
                      label: labels[index],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseStep extends StatelessWidget {
  const _PhaseStep({
    required this.index,
    required this.total,
    required this.step,
    required this.label,
  });

  final int index;
  final int total;
  final int step;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = BodyColors.of(context);
    final complete = step > index;
    final active = step == index;
    final background = complete
        ? colors.success
        : active
        ? colors.accent
        : colors.surfaceMuted;
    final foreground = complete || active
        ? colors.onAccent
        : colors.secondaryInk;

    final labelStyle = BodyType.caption.copyWith(
      fontSize: 11,
      color: active ? colors.ink : colors.secondaryInk,
    );

    // Half of the line to each neighbour. Columns are equal width, so the
    // halves meet at the column edges and read as one line behind the circles.
    Widget connector({required bool shown, required bool reached}) => Expanded(
      child: shown
          ? Container(height: 2, color: reached ? colors.accent : colors.border)
          : const SizedBox.shrink(),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                children: [
                  connector(shown: index > 0, reached: index <= step),
                  connector(shown: index < total - 1, reached: index < step),
                ],
              ),
              AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : BodyMotion.fast,
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active || complete
                        ? background
                        : colors.controlBorder,
                  ),
                ),
                child: Center(
                  child: complete
                      ? Icon(Icons.check_rounded, size: 18, color: foreground)
                      : Text(
                          '${index + 1}',
                          style: BodyType.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: foreground,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: BodySpace.xs),
        // Four steps can be narrow at large text sizes. Shrink the label
        // instead of breaking it mid-word, centred in a full-line slot so
        // labels that shrink by different amounts still share a line.
        SizedBox(
          height:
              (MediaQuery.textScalerOf(context).scale(labelStyle.fontSize!) *
                      labelStyle.height!)
                  .ceilToDouble(),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, style: labelStyle),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

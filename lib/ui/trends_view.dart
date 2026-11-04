import 'dart:math' as math;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/measurement.dart';
import 'body_format.dart';
import 'body_tokens.dart';
import 'widgets/body_surface.dart';

class TrendsView extends StatelessWidget {
  const TrendsView({
    super.key,
    required this.history,
    required this.loadingHistory,
    required this.notice,
    required this.onAddMeasurement,
    required this.bottomClearance,
  });

  final List<Measurement> history;
  final bool loadingHistory;
  final DashboardNotice? notice;
  final VoidCallback? onAddMeasurement;
  final double bottomClearance;

  @override
  Widget build(BuildContext context) {
    final colors = BodyColors.of(context);
    final newest = history.isEmpty ? null : history.first;
    final oldest = history.isEmpty ? null : history.last;
    final subtitle = loadingHistory
        ? 'Loading your readings…'
        : newest == null
            ? 'No readings yet'
            : '${history.length} ${history.length == 1 ? 'reading' : 'readings'}'
                ' · ${formatDateRange(context, oldest!.timestamp, newest.timestamp)}';

    return BodyListView(
      storageKey: const PageStorageKey<String>('trends'),
      bottom: bottomClearance,
      children: [
        NoticeSlot(notice: notice),
        Text(
          'Weight trend',
          style: BodyType.title.copyWith(color: colors.ink),
        ),
        const SizedBox(height: BodySpace.xs),
        Text(
          subtitle,
          style: BodyType.caption.copyWith(color: colors.secondaryInk),
        ),
        const SizedBox(height: BodySpace.lg),
        if (loadingHistory)
          const LoadingPanel(message: 'Loading saved readings…')
        else if (history.isEmpty)
          EmptyPanel(
            icon: Icons.show_chart_rounded,
            title: 'No readings yet',
            message:
                'Take a measurement or add a weight manually to start your trend.',
            actionLabel: onAddMeasurement == null ? null : 'Add weight',
            onAction: onAddMeasurement,
          )
        else if (history.length == 1)
          _SingleReadingCard(
            measurement: history.first,
            onAddMeasurement: onAddMeasurement,
          )
        else
          _ChartCard(history: history),
        if (!loadingHistory && history.isNotEmpty) ...[
          const SizedBox(height: BodySpace.xl),
          const SectionLabel('Recent readings'),
          const SizedBox(height: BodySpace.md),
          _RecentReadings(history: history),
        ],
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.history});

  final List<Measurement> history;

  @override
  Widget build(BuildContext context) {
    final colors = BodyColors.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final points = [...history]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return SurfaceCard(
      padding: const EdgeInsets.all(BodySpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 240,
            child: _WeightChart(
              measurements: points,
              reduceMotion: reduceMotion,
            ),
          ),
          const SizedBox(height: BodySpace.sm),
          Text(
            'Tap a point for its date and weight.',
            style: BodyType.caption.copyWith(color: colors.secondaryInk),
          ),
        ],
      ),
    );
  }
}

class _WeightChart extends StatelessWidget {
  const _WeightChart({
    required this.measurements,
    required this.reduceMotion,
  });

  final List<Measurement> measurements;
  final bool reduceMotion;

  DateTime _dateFor(double x, bool useTime, DateTime first) {
    if (!useTime) {
      final index = x.round().clamp(0, measurements.length - 1);
      return measurements[index].timestamp;
    }
    return first.add(
      Duration(milliseconds: (x * Duration.millisecondsPerDay).round()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = BodyColors.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);
    final first = measurements.first.timestamp;
    final last = measurements.last.timestamp;
    final spanSeconds = last.difference(first).inSeconds;
    final useTime = spanSeconds >= 60;
    final xs = [
      for (var index = 0; index < measurements.length; index++)
        useTime
            ? measurements[index].timestamp.difference(first).inSeconds /
                Duration.secondsPerDay
            : index.toDouble(),
    ];
    final weights = measurements.map((item) => item.weightKg).toList();
    final minWeight = weights.reduce(math.min);
    final maxWeight = weights.reduce(math.max);
    final middle = (minWeight + maxWeight) / 2;
    final minY = maxWeight - minWeight < 2 ? middle - 1 : minWeight - 0.2;
    final maxY = maxWeight - minWeight < 2 ? middle + 1 : maxWeight + 0.2;
    final interval = math.max((maxY - minY) / 2, 0.1);
    final minX = xs.first;
    final maxX = xs.last;
    final xInterval = useTime
        ? (maxX - minX) /
            (measurements.length <= 3 ? measurements.length - 1 : 2)
        : (measurements.length <= 3 ? 1.0 : (maxX - minX) / 2);
    final sameDay = first.year == last.year &&
        first.month == last.month &&
        first.day == last.day;

    final spots = [
      for (var index = 0; index < measurements.length; index++)
        FlSpot(xs[index], weights[index]),
    ];

    final chart = LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        clipData: FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: colors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: Text(
              'kg',
              style: BodyType.caption.copyWith(
                fontSize: 11,
                color: colors.secondaryInk,
              ),
            ),
            axisNameSize: 18,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40 * textScale,
              interval: interval,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                axisSide: meta.axisSide,
                space: 6,
                child: Text(
                  value.toStringAsFixed(1),
                  style: BodyType.caption.copyWith(
                    fontSize: 11,
                    color: colors.secondaryInk,
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32 * textScale,
              interval: xInterval,
              getTitlesWidget: (value, meta) {
                final date = _dateFor(value, useTime, first);
                final label = sameDay
                    ? formatTime(context, date)
                    : formatDay(context, date);
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 6,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(
                    label,
                    style: BodyType.caption.copyWith(
                      fontSize: 11,
                      color: colors.secondaryInk,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colors.surfaceRaised,
            tooltipBorder: BorderSide(color: colors.border),
            tooltipRoundedRadius: BodyRadius.control,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: BodySpace.md,
              vertical: BodySpace.sm,
            ),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            maxContentWidth: 180,
            getTooltipItems: (touchedSpots) => [
              for (final spot in touchedSpots)
                LineTooltipItem(
                  '${formatWeight(spot.y)} kg\n'
                  '${formatDateTime(context, _dateFor(spot.x, useTime, first))}',
                  BodyType.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            barWidth: 2.5,
            color: colors.chartLine,
            dotData: FlDotData(show: measurements.length <= 20),
            belowBarData: BarAreaData(
              show: true,
              color: colors.chartLine.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );

    final summary = 'Weight trend, ${measurements.length} readings from '
        '${formatDay(context, first)} to ${formatDay(context, last)}. '
        'Lowest ${formatWeight(minWeight)} kilograms, highest '
        '${formatWeight(maxWeight)} kilograms. Latest '
        '${formatWeight(weights.last)} kilograms.';

    return RepaintBoundary(
      child: Semantics(
        container: true,
        label: summary,
        child: ExcludeSemantics(
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: chart,
          ),
        ),
      ),
    );
  }
}

class _SingleReadingCard extends StatelessWidget {
  const _SingleReadingCard({
    required this.measurement,
    required this.onAddMeasurement,
  });

  final Measurement measurement;
  final VoidCallback? onAddMeasurement;

  @override
  Widget build(BuildContext context) {
    final colors = BodyColors.of(context);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${formatWeight(measurement.weightKg)} kg',
            style: BodyType.title.copyWith(
              fontSize: 28,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: BodySpace.xs),
          Text(
            formatDateTime(context, measurement.timestamp),
            style: BodyType.caption.copyWith(color: colors.secondaryInk),
          ),
          const SizedBox(height: BodySpace.md),
          Text(
            'Your trend will appear after your next reading.',
            style: BodyType.caption.copyWith(color: colors.secondaryInk),
          ),
          if (onAddMeasurement != null) ...[
            const SizedBox(height: BodySpace.lg),
            SizedBox(
              width: double.infinity,
              child: AdaptiveButton(
                onPressed: onAddMeasurement,
                label: 'Add another weight',
                style: AdaptiveButtonStyle.plain,
                size: AdaptiveButtonSize.large,
                minSize: const Size(0, BodySpace.minimumTapTarget),
                // Native iOS 26 title buttons with a zero min width render
                // without a tappable area.
                useNative: false,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentReadings extends StatelessWidget {
  const _RecentReadings({required this.history});

  final List<Measurement> history;

  @override
  Widget build(BuildContext context) {
    final colors = BodyColors.of(context);
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < history.length; index++) ...[
            _ReadingRow(measurement: history[index]),
            if (index < history.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: colors.border,
                indent: BodySpace.lg,
                endIndent: BodySpace.lg,
              ),
          ],
        ],
      ),
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({required this.measurement});

  final Measurement measurement;

  @override
  Widget build(BuildContext context) {
    final colors = BodyColors.of(context);
    final isScale = measurement.impedance != null;
    final source = isScale ? 'Scale reading' : 'Manual entry';
    final date = formatDateTime(context, measurement.timestamp);
    final bmiLabel =
        measurement.bmi == null ? null : 'BMI ${formatBmi(measurement.bmi)}';
    final stack = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final semantics = '$date, ${spokenWeight(measurement.weightKg)}, $source'
        '${bmiLabel == null ? '' : ', $bmiLabel'}';

    return Semantics(
      container: true,
      label: semantics,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BodySpace.lg,
          vertical: BodySpace.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isScale
                    ? Icons.monitor_weight_outlined
                    : Icons.edit_note_rounded,
                color: isScale ? colors.accentText : colors.secondaryInk,
                size: 20,
              ),
            ),
            const SizedBox(width: BodySpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${formatWeight(measurement.weightKg)} kg',
                    style: BodyType.title.copyWith(
                      fontSize: 18,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$date · $source',
                    style: BodyType.caption.copyWith(
                      color: colors.secondaryInk,
                    ),
                  ),
                  if (stack && bmiLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      bmiLabel,
                      style: BodyType.caption.copyWith(
                        color: colors.accentText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!stack && bmiLabel != null)
              Text(
                bmiLabel,
                style: BodyType.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.accentText,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

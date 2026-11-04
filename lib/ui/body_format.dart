import 'package:flutter/material.dart';

/// Display formatting shared by the dashboard, chart and dialogs.
String formatWeight(double kilograms) => kilograms.toStringAsFixed(1);

String formatBmi(double? bmi) => bmi?.toStringAsFixed(1) ?? '—';

String formatBodyFat(double? percent) =>
    percent == null ? '—' : '${percent.toStringAsFixed(1)}%';

String formatImpedance(int? ohms) => ohms == null ? '—' : '$ohms Ω';

String formatHeight(double centimeters) {
  final whole = centimeters.roundToDouble();
  return centimeters == whole
      ? '${whole.toStringAsFixed(0)} cm'
      : '${centimeters.toStringAsFixed(1)} cm';
}

/// Formats a stored height without a unit for a text-field initial value.
String formatHeightInput(double centimeters) {
  final whole = centimeters.roundToDouble();
  return centimeters == whole
      ? whole.toStringAsFixed(0)
      : centimeters.toStringAsFixed(1);
}

String formatSex(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1).toLowerCase();
}

/// Neutral change copy. Never implies that a change is good or bad.
String formatWeightDelta(double latest, double previous) {
  final difference = latest - previous;
  if (difference.abs() < 0.05) return 'Same as your previous reading';
  final direction = difference > 0 ? 'above' : 'below';
  return '${difference.abs().toStringAsFixed(1)} kg $direction your previous reading';
}

String formatTime(BuildContext context, DateTime value) {
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(value),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

/// Compact timestamp: "Today, 09:41", "Yesterday, 21:10" or "4 Nov, 09:41".
String formatDateTime(BuildContext context, DateTime value) {
  final now = DateTime.now();
  final date = DateTime(value.year, value.month, value.day);
  final today = DateTime(now.year, now.month, now.day);
  final dayDifference = today.difference(date).inDays;
  final time = formatTime(context, value);
  if (dayDifference == 0) return 'Today, $time';
  if (dayDifference == 1) return 'Yesterday, $time';
  final dateLabel = MaterialLocalizations.of(context).formatShortMonthDay(value);
  return '$dateLabel, $time';
}

/// Date without time, used in summaries: "4 Nov".
String formatDay(BuildContext context, DateTime value) =>
    MaterialLocalizations.of(context).formatShortMonthDay(value);

/// Compact date range for the trend subtitle.
String formatDateRange(
  BuildContext context,
  DateTime first,
  DateTime last,
) {
  if (first.year == last.year &&
      first.month == last.month &&
      first.day == last.day) {
    return formatDay(context, first);
  }
  final start = formatDay(context, first);
  final end = formatDay(context, last);
  if (first.year == last.year) return '$start – $end';
  return '$start ${first.year} – $end ${last.year}';
}

/// "90.2 kilograms" for screen-reader labels.
String spokenWeight(double kilograms) =>
    '${kilograms.toStringAsFixed(1)} kilograms';

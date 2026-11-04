import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user_profile.dart';
import 'body_format.dart';
import 'body_tokens.dart';

bool _isCupertino(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS;

/// Edits or creates the measurement profile. Returns null when cancelled.
Future<UserProfile?> showProfileDialog(
  BuildContext context, {
  UserProfile? initialProfile,
}) {
  if (_isCupertino(context)) {
    return showCupertinoSheet<UserProfile>(
      context: context,
      scrollableBuilder: (sheetContext, scrollController) => _ProfilePage(
        initialProfile: initialProfile,
        cupertino: true,
        scrollController: scrollController,
      ),
    );
  }
  return showDialog<UserProfile>(
    context: context,
    builder: (_) => _ProfilePage(
      initialProfile: initialProfile,
      cupertino: false,
    ),
  );
}

/// Adds a manual weight. Returns null when cancelled.
Future<double?> showManualWeightDialog(BuildContext context) {
  if (_isCupertino(context)) {
    return showCupertinoSheet<double>(
      context: context,
      scrollableBuilder: (sheetContext, scrollController) => _WeightPage(
        cupertino: true,
        scrollController: scrollController,
      ),
    );
  }
  return showDialog<double>(
    context: context,
    builder: (_) => _WeightPage(cupertino: false),
  );
}

/// Recovery dialog for Bluetooth permission. The adaptive alert dismisses
/// itself before invoking the action, so the action only opens Settings.
Future<void> showBluetoothPermissionDialog(
  BuildContext context, {
  required Future<bool> Function() openSettings,
  bool permanent = true,
}) {
  return AdaptiveAlertDialog.show(
    context: context,
    title: 'Bluetooth access needed',
    message: permanent
        ? 'Allow Bluetooth access in Settings so the app can find your scale.'
        : 'Bluetooth permission is required to connect to your scale.',
    actions: [
      AlertAction(
        title: 'Not now',
        style: AlertActionStyle.cancel,
        onPressed: () {},
      ),
      AlertAction(
        title: 'Open settings',
        // A preferred action is rendered as a filled button by the native
        // iOS 26 alert, which forces white text. The light dark-mode accent
        // cannot carry white text, so keep the native tinted-button style.
        style: AlertActionStyle.defaultAction,
        onPressed: () => unawaited(openSettings()),
      ),
    ],
  );
}

/// Confirmation for discarding unreadable saved history.
Future<void> showResetHistoryDialog(
  BuildContext context, {
  required Future<void> Function() onReset,
}) {
  return AdaptiveAlertDialog.show(
    context: context,
    title: 'Reset saved readings?',
    message:
        'This removes the unreadable history from this device. Your profile is kept.',
    actions: [
      AlertAction(
        title: 'Cancel',
        style: AlertActionStyle.cancel,
        onPressed: () {},
      ),
      AlertAction(
        title: 'Reset',
        style: AlertActionStyle.destructive,
        onPressed: () => unawaited(onReset()),
      ),
    ],
  );
}

class _ProfilePage extends StatefulWidget {
  const _ProfilePage({
    required this.initialProfile,
    required this.cupertino,
    this.scrollController,
  });

  final UserProfile? initialProfile;
  final bool cupertino;
  final ScrollController? scrollController;

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late String _sex = widget.initialProfile?.sex ?? 'male';
  String? _heightInput;
  String? _ageInput;
  bool _popping = false;

  bool get _creating => widget.initialProfile == null;

  void _cancel() {
    if (_popping) return;
    _popping = true;
    Navigator.of(context).pop();
  }

  void _save() {
    if (_popping) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    form.save();
    final height = double.tryParse(
      (_heightInput ?? '').replaceAll(',', '.'),
    );
    final age = int.tryParse(_ageInput ?? '');
    if (height == null || age == null) return;
    final profile = UserProfile(heightCm: height, ageYears: age, sex: _sex);
    if (!profile.valid) return;
    _popping = true;
    Navigator.of(context).pop(profile);
  }

  @override
  Widget build(BuildContext context) {
    return widget.cupertino ? _buildCupertino(context) : _buildMaterial(context);
  }

  Widget _buildCupertino(BuildContext context) {
    final colors = BodyColors.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Measurement profile'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _cancel,
          child: const Text('Cancel'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _save,
          child: const Text('Save'),
        ),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            controller: widget.scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              0,
              BodySpace.lg,
              0,
              BodySpace.xl + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              CupertinoFormSection.insetGrouped(
                header: const Text('Your measurements'),
                footer: const Text(
                  'Height, age and sex are only used to estimate body composition.',
                ),
                children: [
                  CupertinoTextFormFieldRow(
                    prefix: const Text('Height (cm)'),
                    placeholder: 'e.g. 175',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: _decimalFormatters(),
                    textInputAction: TextInputAction.next,
                    autofocus: _creating,
                    initialValue: _creating
                        ? ''
                        : formatHeightInput(widget.initialProfile!.heightCm),
                    validator: _validateHeight,
                    onSaved: (value) => _heightInput = value?.trim(),
                  ),
                  CupertinoTextFormFieldRow(
                    prefix: const Text('Age (years)'),
                    placeholder: 'e.g. 35',
                    keyboardType: TextInputType.number,
                    inputFormatters: _integerFormatters(),
                    textInputAction: TextInputAction.done,
                    initialValue: _creating
                        ? ''
                        : widget.initialProfile!.ageYears.toString(),
                    validator: _validateAge,
                    onSaved: (value) => _ageInput = value?.trim(),
                    onFieldSubmitted: (_) => _save(),
                  ),
                ],
              ),
              const SizedBox(height: BodySpace.xl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BodySpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sex for estimation formulas',
                      style: BodyType.caption.copyWith(
                        color: colors.secondaryInk,
                      ),
                    ),
                    const SizedBox(height: BodySpace.sm),
                    AdaptiveSegmentedControl(
                      labels: const ['Male', 'Female'],
                      selectedIndex: _sex == 'male' ? 0 : 1,
                      height: BodySpace.minimumTapTarget,
                      textColor: colors.ink,
                      selectedTextColor: colors.ink,
                      onValueChanged: (index) {
                        setState(() => _sex = index == 0 ? 'male' : 'female');
                      },
                    ),
                    const SizedBox(height: BodySpace.sm),
                    Text(
                      'These are estimates, not medical measurements.',
                      style: BodyType.caption.copyWith(
                        color: colors.secondaryInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaterial(BuildContext context) {
    final colors = BodyColors.of(context);
    return AlertDialog(
      backgroundColor: colors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: BodySpace.xl,
        vertical: BodySpace.xl,
      ),
      scrollable: true,
      title: const Text('Measurement profile'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              initialValue: _creating
                  ? ''
                  : formatHeightInput(widget.initialProfile!.heightCm),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: _decimalFormatters(),
              textInputAction: TextInputAction.next,
              autofocus: _creating,
              decoration: const InputDecoration(
                labelText: 'Height',
                suffixText: 'cm',
                errorMaxLines: 2,
              ),
              validator: _validateHeight,
              onSaved: (value) => _heightInput = value?.trim(),
            ),
            const SizedBox(height: BodySpace.lg),
            TextFormField(
              initialValue: _creating
                  ? ''
                  : widget.initialProfile!.ageYears.toString(),
              keyboardType: TextInputType.number,
              inputFormatters: _integerFormatters(),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Age',
                suffixText: 'years',
                errorMaxLines: 2,
              ),
              validator: _validateAge,
              onSaved: (value) => _ageInput = value?.trim(),
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: BodySpace.xl),
            Text(
              'Sex for estimation formulas',
              style: BodyType.caption.copyWith(color: colors.secondaryInk),
            ),
            const SizedBox(height: BodySpace.sm),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'male', label: Text('Male')),
                ButtonSegment(value: 'female', label: Text('Female')),
              ],
              selected: {_sex},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                setState(() => _sex = selection.first);
              },
            ),
            const SizedBox(height: BodySpace.sm),
            Text(
              'These are estimates, not medical measurements.',
              style: BodyType.caption.copyWith(color: colors.secondaryInk),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _cancel, child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _WeightPage extends StatefulWidget {
  const _WeightPage({required this.cupertino, this.scrollController});

  final bool cupertino;
  final ScrollController? scrollController;

  @override
  State<_WeightPage> createState() => _WeightPageState();
}

class _WeightPageState extends State<_WeightPage> {
  final _formKey = GlobalKey<FormState>();
  String? _weightInput;
  bool _popping = false;

  void _cancel() {
    if (_popping) return;
    _popping = true;
    Navigator.of(context).pop();
  }

  void _save() {
    if (_popping) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    form.save();
    final weight = double.tryParse((_weightInput ?? '').replaceAll(',', '.'));
    if (weight == null || weight < 1 || weight > 350) return;
    _popping = true;
    Navigator.of(context).pop(weight);
  }

  @override
  Widget build(BuildContext context) {
    return widget.cupertino ? _buildCupertino(context) : _buildMaterial(context);
  }

  Widget _buildCupertino(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Add weight'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _cancel,
          child: const Text('Cancel'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _save,
          child: const Text('Save'),
        ),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            controller: widget.scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              0,
              BodySpace.lg,
              0,
              BodySpace.xl + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              CupertinoFormSection.insetGrouped(
                header: const Text('Manual entry'),
                footer: const Text(
                  'Adds weight to your history. Body composition estimates need a scale reading.',
                ),
                children: [
                  CupertinoTextFormFieldRow(
                    prefix: const Text('Weight (kg)'),
                    placeholder: 'e.g. 72.4',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: _decimalFormatters(),
                    textInputAction: TextInputAction.done,
                    autofocus: true,
                    validator: _validateWeight,
                    onSaved: (value) => _weightInput = value?.trim(),
                    onFieldSubmitted: (_) => _save(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaterial(BuildContext context) {
    final colors = BodyColors.of(context);
    return AlertDialog(
      backgroundColor: colors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: BodySpace.xl,
        vertical: BodySpace.xl,
      ),
      scrollable: true,
      title: const Text('Add weight'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: _decimalFormatters(),
              textInputAction: TextInputAction.done,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Weight',
                suffixText: 'kg',
                helperText:
                    'Adds weight to your history. Body composition estimates need a scale reading.',
                helperMaxLines: 3,
                errorMaxLines: 2,
              ),
              validator: _validateWeight,
              onSaved: (value) => _weightInput = value?.trim(),
              onFieldSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _cancel, child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

String? _validateHeight(String? value) {
  final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
  if (parsed == null) return 'Enter your height in centimetres.';
  if (parsed < 100 || parsed > 250) {
    return 'Height must be between 100 and 250 cm.';
  }
  return null;
}

String? _validateAge(String? value) {
  final parsed = int.tryParse((value ?? '').trim());
  if (parsed == null) return 'Enter your age in years.';
  if (parsed < 10 || parsed > 100) {
    return 'Age must be between 10 and 100 years.';
  }
  return null;
}

String? _validateWeight(String? value) {
  final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
  if (parsed == null) return 'Enter a weight in kilograms.';
  if (parsed < 1 || parsed > 350) {
    return 'Weight must be between 1 and 350 kg.';
  }
  return null;
}

List<TextInputFormatter> _decimalFormatters() => [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      LengthLimitingTextInputFormatter(6),
    ];

List<TextInputFormatter> _integerFormatters() => [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(3),
    ];

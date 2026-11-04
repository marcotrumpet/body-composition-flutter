import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'body_tokens.dart';

class GarminCredentials {
  const GarminCredentials({required this.email, required this.password});

  final String email;
  final String password;
}

bool _isCupertino(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS;

/// Sign-in form for Garmin Connect. Returns null when cancelled.
Future<GarminCredentials?> showGarminLoginDialog(
  BuildContext context, {
  String? initialEmail,
}) {
  if (_isCupertino(context)) {
    return showCupertinoSheet<GarminCredentials>(
      context: context,
      scrollableBuilder: (sheetContext, scrollController) => _GarminLoginPage(
        cupertino: true,
        initialEmail: initialEmail,
        scrollController: scrollController,
      ),
    );
  }
  return showDialog<GarminCredentials>(
    context: context,
    builder: (_) =>
        _GarminLoginPage(cupertino: false, initialEmail: initialEmail),
  );
}

/// Asks for the verification code Garmin sends when MFA is enabled.
Future<String?> showGarminMfaDialog(
  BuildContext context, {
  required String method,
  String? email,
}) {
  if (_isCupertino(context)) {
    return showCupertinoSheet<String>(
      context: context,
      scrollableBuilder: (sheetContext, scrollController) => _GarminMfaPage(
        cupertino: true,
        method: method,
        email: email,
        scrollController: scrollController,
      ),
    );
  }
  return showDialog<String>(
    context: context,
    builder: (_) =>
        _GarminMfaPage(cupertino: false, method: method, email: email),
  );
}

/// Confirmation before removing the saved Garmin session.
Future<void> showGarminDisconnectDialog(
  BuildContext context, {
  required Future<void> Function() onDisconnect,
}) {
  return AdaptiveAlertDialog.show(
    context: context,
    title: 'Disconnect Garmin?',
    message:
        'New readings will stop syncing until you connect again. Readings '
        'already in Garmin Connect are kept.',
    actions: [
      AlertAction(
        title: 'Cancel',
        style: AlertActionStyle.cancel,
        onPressed: () {},
      ),
      AlertAction(
        title: 'Disconnect',
        style: AlertActionStyle.destructive,
        onPressed: () => unawaited(onDisconnect()),
      ),
    ],
  );
}

class _GarminLoginPage extends StatefulWidget {
  const _GarminLoginPage({
    required this.cupertino,
    required this.initialEmail,
    this.scrollController,
  });

  final bool cupertino;
  final String? initialEmail;
  final ScrollController? scrollController;

  @override
  State<_GarminLoginPage> createState() => _GarminLoginPageState();
}

class _GarminLoginPageState extends State<_GarminLoginPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController = TextEditingController(
    text: widget.initialEmail ?? '',
  );
  final _passwordController = TextEditingController();
  bool _popping = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _cancel() {
    if (_popping) return;
    _popping = true;
    Navigator.of(context).pop();
  }

  void _save() {
    if (_popping) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    _popping = true;
    Navigator.of(context).pop(
      GarminCredentials(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.cupertino
        ? _buildCupertino(context)
        : _buildMaterial(context);
  }

  Widget _buildCupertino(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Connect Garmin'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _cancel,
          child: const Text('Cancel'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _save,
          child: const Text('Sign in'),
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
                header: const Text('Garmin account'),
                footer: const Text(
                  'Your password is sent only to Garmin to authorize this '
                  'device. It is not saved.',
                ),
                children: [
                  CupertinoTextFormFieldRow(
                    prefix: const Text('Email'),
                    placeholder: 'you@example.com',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    validator: _validateEmail,
                  ),
                  CupertinoTextFormFieldRow(
                    prefix: const Text('Password'),
                    placeholder: 'Required',
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    validator: _validatePassword,
                    onFieldSubmitted: (_) => _save(),
                  ),
                ],
              ),
              const SizedBox(height: BodySpace.xl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BodySpace.lg),
                child: Text(
                  'Garmin may send a verification code the first time this '
                  'device signs in.',
                  style: BodyType.caption.copyWith(
                    color: BodyColors.of(context).secondaryInk,
                  ),
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
      title: const Text('Connect Garmin'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                errorMaxLines: 2,
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: BodySpace.lg),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Password',
                helperText:
                    'Sent only to Garmin to authorize this device. It is not '
                    'saved.',
                helperMaxLines: 3,
                errorMaxLines: 2,
              ),
              validator: _validatePassword,
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: BodySpace.md),
            Text(
              'Garmin may send a verification code the first time this device '
              'signs in.',
              style: BodyType.caption.copyWith(color: colors.secondaryInk),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _cancel, child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Sign in')),
      ],
    );
  }
}

class _GarminMfaPage extends StatefulWidget {
  const _GarminMfaPage({
    required this.cupertino,
    required this.method,
    required this.email,
    this.scrollController,
  });

  final bool cupertino;
  final String method;
  final String? email;
  final ScrollController? scrollController;

  @override
  State<_GarminMfaPage> createState() => _GarminMfaPageState();
}

class _GarminMfaPageState extends State<_GarminMfaPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _popping = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String get _hint => switch (widget.method) {
    'sms' => 'Enter the code Garmin texted you.',
    'email' => 'Enter the code Garmin emailed you.',
    _ => 'Enter the verification code from Garmin.',
  };

  String get _footer {
    final email = widget.email;
    final target = email == null || email.isEmpty ? '' : ' Sent to $email.';
    return '$_hint$target Garmin only asks for a code when MFA is enabled.';
  }

  void _cancel() {
    if (_popping) return;
    _popping = true;
    Navigator.of(context).pop();
  }

  void _save() {
    if (_popping) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    _popping = true;
    Navigator.of(context).pop(_codeController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return widget.cupertino
        ? _buildCupertino(context)
        : _buildMaterial(context);
  }

  Widget _buildCupertino(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Verification'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _cancel,
          child: const Text('Cancel'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _save,
          child: const Text('Verify'),
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
                header: const Text('Garmin verification'),
                footer: Text(_footer),
                children: [
                  CupertinoTextFormFieldRow(
                    prefix: const Text('Code'),
                    placeholder: '123456',
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    textInputAction: TextInputAction.done,
                    autofocus: true,
                    inputFormatters: [LengthLimitingTextInputFormatter(12)],
                    validator: _validateCode,
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
      title: const Text('Garmin verification'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              textInputAction: TextInputAction.done,
              autofocus: true,
              inputFormatters: [LengthLimitingTextInputFormatter(12)],
              decoration: const InputDecoration(
                labelText: 'Code',
                errorMaxLines: 2,
              ),
              validator: _validateCode,
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: BodySpace.md),
            Text(
              _footer,
              style: BodyType.caption.copyWith(color: colors.secondaryInk),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _cancel, child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Verify')),
      ],
    );
  }
}

String? _validateEmail(String? value) {
  final email = (value ?? '').trim();
  if (email.isEmpty) return 'Enter the email for your Garmin account.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Enter a valid email address.';
  }
  return null;
}

String? _validatePassword(String? value) {
  if ((value ?? '').isEmpty) return 'Enter your Garmin password.';
  return null;
}

String? _validateCode(String? value) {
  final code = (value ?? '').trim();
  if (code.isEmpty) return 'Enter the verification code from Garmin.';
  if (code.length < 4) return 'The verification code is too short.';
  return null;
}

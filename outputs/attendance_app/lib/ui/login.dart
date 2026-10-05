import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../data/controller.dart';
import '../data/portal_service.dart';
import '../data/portal_parser.dart';
import 'shared.dart';

class LoginScreen extends StatefulWidget {
  final AppController controller;
  const LoginScreen(this.controller, {super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final username = TextEditingController(),
      password = TextEditingController(),
      captcha = TextEditingController();
  LoginChallenge? challenge;
  bool loading = false, submitting = false, hidden = true;
  String? error;
  @override
  void initState() {
    super.initState();
    restoreLogin();
  }

  Future<void> restoreLogin() async {
    setState(() => loading = true);
    bool saved = false;
    String? restoreError = widget.controller.error;
    try {
      final value = await widget.controller.credentials.read();
      if (!mounted) return;
      if (value != null) {
        username.text = value.username;
        password.text = value.password;
        saved = true;
      }
    } catch (_) {
      restoreError =
          'Saved login could not be read. Sign in once to save it again.';
    }
    if (!mounted) return;
    await refresh(keepError: restoreError);
    // One automatic attempt per screen entry; rejected OCR falls back to manual.
    if (mounted && saved && challenge != null && captcha.text.isNotEmpty) {
      await submit();
    }
  }

  String describe(Object e) {
    if (e is DioException) {
      return switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout =>
          'IMS took too long to respond. Tap Refresh CAPTCHA to try again.',
        DioExceptionType.badCertificate =>
          'The IMS HTTPS certificate could not be verified. Check your device date and connection.',
        DioExceptionType.badResponse =>
          'IMS returned HTTP ${e.response?.statusCode ?? 'error'}. Refresh the CAPTCHA to try again.',
        _ =>
          'Could not connect to IMS. Check your connection and refresh the CAPTCHA.',
      };
    }
    return e is PortalException
        ? e.message
        : 'Could not complete the IMS request. Please try again.';
  }

  Future<void> refresh({String? keepError}) async {
    setState(() {
      loading = true;
      challenge = null;
      captcha.clear();
      error = keepError;
    });
    try {
      final value = await widget.controller.portal.challenge();
      if (!mounted) return;
      setState(() => challenge = value);
      try {
        final answer = await widget.controller.captchaService.recognize(
          value.image,
        );
        if (mounted && answer != null) captcha.text = answer;
      } catch (_) {
        /* The visible CAPTCHA can always be entered manually. */
      }
    } catch (e) {
      if (mounted) setState(() => error = describe(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submit() async {
    if (challenge == null || loading || submitting) return;
    if (username.text.trim().isEmpty ||
        password.text.isEmpty ||
        captcha.text.trim().isEmpty) {
      setState(
        () =>
            error = 'Enter your student ID, password and the security number.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await widget.controller.signIn(
        challenge!,
        username.text,
        password.text,
        captcha.text,
      );
      try {
        await MethodChannel(
          'dev.attendly/permission',
        ).invokeMethod('requestOnce');
      } catch (_) {}
    } on PortalLoginRejected catch (e) {
      if (mounted) await refresh(keepError: e.message);
    } catch (e) {
      if (mounted) setState(() => error = describe(e));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    captcha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.grain_rounded,
                        color: tone(context, green),
                        size: 30,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'attendly',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: tone(context, ink),
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 34),
                  Heading(
                    'Your university. Your attendance.',
                    'Sign in to IMS',
                    'Connect your NSUT student account to see your attendance and plan your leaves.',
                  ),
                  Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          key: Key('ims-username'),
                          controller: username,
                          enabled: !submitting,
                          autofillHints: [AutofillHints.username],
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Student ID',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        SizedBox(height: 14),
                        TextField(
                          key: Key('ims-password'),
                          controller: password,
                          enabled: !submitting,
                          autofillHints: [AutofillHints.password],
                          obscureText: hidden,
                          enableSuggestions: false,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'IMS password',
                            prefixIcon: Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: hidden
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () => setState(() => hidden = !hidden),
                              icon: Icon(
                                hidden
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'SECURITY NUMBER',
                          style: TextStyle(
                            color: tone(context, muted),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          height: 90,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: tone(context, paper),
                            border: Border.all(color: tone(context, line)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: loading && challenge == null
                              ? Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : challenge == null
                              ? Center(
                                  child: Text(
                                    'Refresh to load the IMS CAPTCHA',
                                    style: TextStyle(
                                      color: tone(context, muted),
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              : Image.memory(
                                  challenge!.image,
                                  key: Key('ims-captcha-image'),
                                  fit: BoxFit.contain,
                                  gaplessPlayback: false,
                                  errorBuilder: (_, e, s) => Center(
                                    child: Text(
                                      'Image could not be displayed. Refresh CAPTCHA.',
                                      style: TextStyle(
                                        color: tone(context, amber),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: loading || submitting
                                ? null
                                : () => refresh(),
                            icon: Icon(Icons.refresh, size: 17),
                            label: Text('Refresh CAPTCHA'),
                          ),
                        ),
                        TextField(
                          key: Key('ims-captcha'),
                          controller: captcha,
                          enabled: !loading && !submitting && challenge != null,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => submit(),
                          decoration: InputDecoration(
                            labelText: 'Enter security number',
                          ),
                        ),
                        if (error != null)
                          Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                error!,
                                style: TextStyle(
                                  color: tone(context, red),
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        SizedBox(height: 22),
                        FilledButton.icon(
                          key: Key('ims-submit'),
                          onPressed: loading || submitting || challenge == null
                              ? null
                              : submit,
                          icon: submitting
                              ? SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                                )
                              : Icon(Icons.arrow_forward_rounded, size: 18),
                          label: Text(
                            submitting ? 'Connecting to IMS…' : 'Sign in',
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 15,
                        color: tone(context, muted),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your login is encrypted on this device for automatic sign-in. Signing out removes it.',
                          style: TextStyle(
                            color: tone(context, muted),
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

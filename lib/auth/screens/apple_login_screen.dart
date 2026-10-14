import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';
import '../../services/apple_auth_service.dart';

class AppleLoginScreen extends StatefulWidget {
  final String deviceFingerprint;
  final Future<AppleCredential?> Function(String)? authenticate;
  final Future<http.Response> Function(Map<String, dynamic>)? challengeRequest,
      request;
  const AppleLoginScreen({
    super.key,
    required this.deviceFingerprint,
    this.authenticate,
    this.challengeRequest,
    this.request,
  });
  @override
  State<AppleLoginScreen> createState() => _AppleLoginScreenState();
}

class _AppleLoginScreenState extends State<AppleLoginScreen> {
  final _first = TextEditingController(),
      _last = TextEditingController(),
      _password = TextEditingController();
  AppleCredential? _credential;
  String? _challenge, _error;
  String _email = '';
  bool _busy = false, _profile = false, _link = false, _terms = false;
  @override
  void initState() {
    super.initState();
    _submit();
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_profile && !_terms) {
      setState(
        () => _error = 'Please accept the terms to create your account.',
      );
      return;
    }
    if (_link && _password.text.isEmpty) {
      setState(() => _error = 'Enter your existing NaijaGo password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_credential == null) {
        final response =
            await (widget.challengeRequest?.call({
                      'deviceFingerprint': widget.deviceFingerprint,
                    }) ??
                    ApiService.post('/api/auth/apple/challenge', {
                      'deviceFingerprint': widget.deviceFingerprint,
                    }))
                .timeout(const Duration(seconds: 30));
        final data = jsonDecode(response.body);
        if (response.statusCode != 200 ||
            data is! Map ||
            data['success'] != true ||
            !RegExp(
              r'^[a-f0-9]{64}$',
            ).hasMatch(data['nonce']?.toString() ?? '') ||
            !RegExp(
              r'^[a-f0-9]{64}$',
            ).hasMatch(data['challengeId']?.toString() ?? '')) {
          throw AppleAuthUnavailable(
            data is Map
                ? data['message']?.toString() ?? 'Apple sign-in is unavailable.'
                : 'Apple sign-in is unavailable.',
          );
        }
        _challenge = data['challengeId'] as String;
        _credential =
            await (widget.authenticate ?? AppleAuthService.authenticate)(
              data['nonce'] as String,
            );
        if (!mounted) return;
        if (_credential == null) {
          Navigator.of(context).pop();
          return;
        }
        if (_first.text.isEmpty) _first.text = _credential!.firstName ?? '';
        if (_last.text.isEmpty) _last.text = _credential!.lastName ?? '';
      }
      final body = <String, dynamic>{
        'app': 'customer',
        'idToken': _credential!.identityToken,
        'challengeId': _challenge,
        'deviceFingerprint': widget.deviceFingerprint,
        if (_link) 'linkPassword': _password.text,
        if (_profile)
          'profile': {
            'firstName': _first.text.trim(),
            'lastName': _last.text.trim(),
            'acceptedTerms': _terms,
          },
      };
      final response =
          await (widget.request?.call(body) ??
                  ApiService.post('/api/auth/apple', body))
              .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) throw const FormatException();
      if (!mounted) return;
      if (response.statusCode == 200) {
        if (data['token'] is! String ||
            (data['token'] as String).isEmpty ||
            data['user'] is! Map ||
            (data['user']['id'] ?? data['user']['_id']) == null ||
            data['loginProvider'] != 'apple') {
          throw const FormatException();
        }
        Navigator.of(context).pop(data);
        return;
      }
      if (response.statusCode == 202 &&
          data['code'] == 'APPLE_PROFILE_REQUIRED' &&
          data['profile'] is Map) {
        setState(() {
          _profile = true;
          _link = false;
          _email = data['profile']['email']?.toString() ?? '';
        });
      } else if (response.statusCode == 409 &&
          data['code'] == 'APPLE_LINK_REQUIRED') {
        setState(() {
          _link = true;
          _profile = false;
        });
      } else {
        if ([
          'APPLE_TOKEN_INVALID',
          'APPLE_CHALLENGE_EXPIRED',
        ].contains(data['code'])) {
          _credential = null;
        }
        setState(
          () => _error =
              data['message']?.toString() ??
              'Apple sign-in failed. Please retry.',
        );
      }
    } on AppleAuthUnavailable catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      // A lost response may have committed account creation. A fresh authorization
      // safely retrieves the same stable subject; never blindly repeat the POST.
      _credential = null;
      if (mounted) {
        setState(
          () => _error =
              'Unable to confirm sign-in. Please try again or use email and password.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sign in with Apple')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_profile) ...[
              Text(_email),
              const SizedBox(height: 16),
              const Text(
                'Your name is optional. You can add delivery details when you place an order.',
              ),
              TextField(
                controller: _first,
                enabled: !_busy,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'First name (optional)',
                ),
              ),
              TextField(
                controller: _last,
                enabled: !_busy,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Last name (optional)',
                ),
              ),
              CheckboxListTile(
                value: _terms,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _terms = v == true),
                title: const Text(
                  'I agree to NaijaGo terms and privacy policy.',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
            if (_link) ...[
              const Text(
                'An existing account uses this email. Verify its NaijaGo password once to link Apple sign-in. Your accounts will not be merged automatically.',
              ),
              TextField(
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                maxLength: 128,
                decoration: const InputDecoration(
                  labelText: 'Existing NaijaGo password',
                ),
              ),
              const Text(
                'Forgot your password? Return to login and use Forgot password.',
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else
              FilledButton(
                onPressed: _submit,
                child: Text(
                  _link
                      ? 'Link and continue'
                      : _profile
                      ? 'Create account'
                      : 'Try again',
                ),
              ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Back to login'),
            ),
          ],
        ),
      ),
    ),
  );
}

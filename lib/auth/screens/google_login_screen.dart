import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';
import '../../services/google_auth_service.dart';

/// Complete Google signup or explicitly link an existing NaijaGo account.
/// This screen never grants vendor approval or supplies an authoritative email.
class GoogleLoginScreen extends StatefulWidget {
  final Future<String?> Function()? authenticate;
  final Future<http.Response> Function(Map<String, dynamic>)? request;
  final String app;
  final String deviceFingerprint;
  final String? oneSignalPlayerId;
  const GoogleLoginScreen({
    super.key,
    required this.app,
    required this.deviceFingerprint,
    this.oneSignalPlayerId,
    this.authenticate,
    this.request,
  });
  @override
  State<GoogleLoginScreen> createState() => _GoogleLoginScreenState();
}

class _GoogleLoginScreenState extends State<GoogleLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String? _idToken;
  String? _error;
  String _email = '';
  bool _busy = false;
  bool _profileRequired = false;
  bool _linkRequired = false;
  bool _acceptedTerms = false;

  @override
  void initState() {
    super.initState();
    _submit();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if ((_profileRequired || _linkRequired) &&
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_profileRequired && !_acceptedTerms) {
      setState(
        () => _error = 'Please accept the terms to create your account.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _idToken ??= await (widget.authenticate ?? GoogleAuthService.idToken)();
      if (!mounted) return;
      if (_idToken == null) {
        Navigator.of(context).pop();
        return;
      }
      final body = <String, dynamic>{
        'app': widget.app,
        'idToken': _idToken,
        'deviceFingerprint': widget.deviceFingerprint,
        if (widget.oneSignalPlayerId != null)
          'oneSignalPlayerId': widget.oneSignalPlayerId,
        if (_linkRequired) 'linkPassword': _password.text,
        if (_profileRequired)
          'profile': {
            'firstName': _firstName.text.trim(),
            'lastName': _lastName.text.trim(),
            'phoneNumber': _phone.text.trim(),
            'acceptedTerms': _acceptedTerms,
          },
      };
      final response =
          await (widget.request?.call(body) ??
                  ApiService.post('/api/auth/google', body))
              .timeout(const Duration(seconds: 30));
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      if (!mounted) return;
      if (response.statusCode == 200) {
        final user = decoded['user'];
        if (decoded['token'] is! String ||
            (decoded['token'] as String).isEmpty ||
            user is! Map ||
            (user['id'] ?? user['_id']) == null) {
          throw const FormatException();
        }
        Navigator.of(context).pop(decoded);
        return;
      }
      if (response.statusCode == 202 &&
          decoded['code'] == 'GOOGLE_PROFILE_REQUIRED') {
        final profile = decoded['profile'];
        if (profile is! Map) {
          throw const FormatException();
        }
        setState(() {
          _profileRequired = true;
          _linkRequired = false;
          _email = profile['email']?.toString() ?? '';
          _firstName.text = profile['firstName']?.toString() ?? '';
          _lastName.text = profile['lastName']?.toString() ?? '';
        });
      } else if (decoded['code'] == 'GOOGLE_LINK_REQUIRED') {
        setState(() {
          _linkRequired = true;
          _profileRequired = false;
        });
      } else {
        if (decoded['code'] == 'GOOGLE_TOKEN_INVALID') _idToken = null;
        setState(
          () => _error =
              decoded['message']?.toString() ??
              'Unable to sign in right now. Please try again.',
        );
      }
    } on GoogleAuthUnavailable catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to connect right now. Please try again or use email and password.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool password = false,
    bool phone = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: password,
        enabled: !_busy,
        keyboardType: phone ? TextInputType.phone : TextInputType.text,
        maxLength: password
            ? 128
            : phone
            ? 14
            : 100,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please complete this field.';
          }
          if (phone &&
              !RegExp(r'^(?:\+?234|0)[789]\d{9}$').hasMatch(value.trim())) {
            return 'Enter a valid Nigerian phone number';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Continue with Google')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_profileRequired) ...[
                  Text(
                    'Complete your account',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(_email),
                  const SizedBox(height: 20),
                  _field(_firstName, 'First name'),
                  _field(_lastName, 'Last name'),
                  _field(_phone, 'Phone number', phone: true),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _acceptedTerms,
                    onChanged: _busy
                        ? null
                        : (value) =>
                              setState(() => _acceptedTerms = value == true),
                    title: const Text(
                      'I agree to NaijaGo terms and privacy policy.',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (widget.app == 'vendor')
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Next, complete your business application. Vendor tools require Admin approval.',
                      ),
                    ),
                ],
                if (_linkRequired) ...[
                  const Text(
                    'An existing NaijaGo account uses this email. Verify its password once to link Google sign-in.',
                  ),
                  const SizedBox(height: 20),
                  _field(
                    _password,
                    'Existing NaijaGo password',
                    password: true,
                  ),
                  const Text(
                    'Forgot your password? Return to the login screen and use Forgot password.',
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_busy)
                  const Center(child: CircularProgressIndicator())
                else
                  FilledButton(
                    onPressed: _submit,
                    child: Text(
                      _linkRequired
                          ? 'Link and continue'
                          : _profileRequired
                          ? 'Create account'
                          : 'Try again',
                    ),
                  ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('Back to login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

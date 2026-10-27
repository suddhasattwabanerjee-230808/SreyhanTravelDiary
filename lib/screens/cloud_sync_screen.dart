import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../cloud_sync.dart';
import '../diary_store.dart';
import '../models.dart';
import '../theme.dart';

/// Account setup and the one-time, per-phone selection for the shared diary.
class CloudSyncScreen extends StatefulWidget {
  const CloudSyncScreen({super.key});

  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  User? _account;
  List<Moment>? _local;
  Set<String> _selected = {};
  bool _busy = false;
  bool _signingIn = false;
  bool _configured = false;
  String? _verificationId;
  int? _resendToken;
  String? _error;
  String? _message;

  String get _normalizedPhone => _phone.text.replaceAll(RegExp(r'[\s()-]'), '');

  CloudDiarySync get _sync => CloudDiarySync.instance;
  DiaryStore get _store => App.of(context).store;

  @override
  void initState() {
    super.initState();
    _configured = _sync.configured;
    _account = _sync.user;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_account != null && _local == null && !_busy) _prepareReview();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _normalizedPhone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (credential) =>
            unawaited(_completePhoneSignIn(credential)),
        verificationFailed: (error) {
          if (mounted) setState(() => _error = _authMessage(error));
        },
        codeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _message = 'Code sent by text message to ${_phone.text.trim()}.';
          });
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (mounted) setState(() => _verificationId = verificationId);
        },
      );
    } catch (error) {
      if (mounted) setState(() => _error = _authMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmCode() async {
    final id = _verificationId;
    if (id == null || _otp.text.trim().length < 6) {
      setState(() => _error = 'Enter the 6-digit code from the text message.');
      return;
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: id,
      smsCode: _otp.text.trim(),
    );
    await _completePhoneSignIn(credential);
  }

  Future<void> _completePhoneSignIn(PhoneAuthCredential credential) async {
    if (_signingIn) return;
    _signingIn = true;
    if (mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    try {
      await _sync.signInWithPhoneCredential(credential, childName: _name.text);
      _account = _sync.user;
      await _prepareReview();
    } catch (error) {
      if (mounted) setState(() => _error = _authMessage(error));
    } finally {
      _signingIn = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _prepareReview() async {
    final account = _account ?? _sync.user;
    if (account == null) return;
    setState(() => _busy = true);
    try {
      if (await _sync.setupComplete(account)) {
        await _sync.syncNow();
        if (mounted) {
          setState(() {
            _account = account;
            _local = null;
            _message = 'This phone is connected and syncing.';
          });
        }
      } else {
        final local = await _sync.localMoments();
        if (mounted) {
          setState(() {
            _account = account;
            _local = local;
            _selected = {for (final m in local) m.id};
            _message = null;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load the diary: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishSync() async {
    final account = _account;
    if (account == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final count = await _sync.finishFirstSync(account, _selected);
      if (mounted) {
        setState(() {
          _local = null;
          _message =
              'Synced $count ${count == 1 ? 'entry' : 'entries'}. Other entries stay only on this phone.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Sync could not finish: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await _sync.signOut();
      if (mounted) {
        setState(() {
          _account = null;
          _local = null;
          _message = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _authMessage(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-phone-number' =>
          'Enter the phone number with its country code, such as +91….',
        'invalid-verification-code' =>
          'That code is not right. Check the text and try again.',
        'code-expired' => 'That code expired. Ask for a new code.',
        'too-many-requests' =>
          'Too many tries. Wait a little before trying again.',
        'quota-exceeded' => 'Firebase SMS limit reached. Try later or check the project billing settings.',
        'operation-not-allowed' =>
          'Turn on Phone sign-in in the Firebase project.',
        'app-not-authorized' => 'Add this app’s SHA-1 and SHA-256 fingerprints in Firebase Project settings.',
        _ => error.message ?? 'Could not connect to the account.',
      };
    }
    return '$error';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Gj.sand,
      appBar: AppBar(title: const Text('Sync across phones')),
      body: SafeArea(
        child: _busy && _account == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  if (!_configured) _notConfigured(),
                  if (_configured && _account == null) _accountForm(),
                  if (_configured && _account != null && _local != null)
                    _reviewEntries(),
                  if (_configured && _account != null && _local == null)
                    _connected(),
                  if (_error != null) _notice(_error!, isError: true),
                  if (_message != null) _notice(_message!),
                  if (_busy) const LinearProgressIndicator(),
                ],
              ),
      ),
    );
  }

  Widget _notConfigured() => _panel(
    icon: Icons.cloud_off_rounded,
    title: 'Firebase needs its app file',
    body: 'Register this Android app in the Firebase project, then add google-services.json. The setup notes are in FIREBASE_SETUP.md.',
  );

  Widget _accountForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _panel(
        icon: Icons.sms_rounded,
        title: 'Sign in with a text code',
        body: 'Use the same phone number on all three phones. Firebase texts a one-time code to that number. The first successful sign-in creates the diary account.',
      ),
      const SizedBox(height: 14),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Form(
            key: _form,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: "Child's name (optional)",
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: const InputDecoration(
                    labelText: 'Phone number with country code',
                    hintText: '+91 98765 43210',
                  ),
                  onChanged: (_) {
                    if (_verificationId != null) {
                      setState(() {
                        _verificationId = null;
                        _resendToken = null;
                        _otp.clear();
                      });
                    }
                  },
                  validator: (v) =>
                      v == null ||
                          !RegExp(r'^\+[1-9]\d{7,14}$')
                              .hasMatch(v.replaceAll(RegExp(r'[\s()-]'), ''))
                      ? 'Enter the full number, including + and country code.'
                      : null,
                ),
                if (_verificationId != null) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _otp,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Text message code',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : _verificationId == null
                      ? _sendCode
                      : _confirmCode,
                  icon: Icon(
                    _verificationId == null
                        ? Icons.sms_rounded
                        : Icons.verified_user_rounded,
                  ),
                  label: Text(
                    _verificationId == null
                        ? 'Send one-time code'
                        : 'Verify code',
                  ),
                ),
                if (_verificationId != null)
                  TextButton(
                    onPressed: _busy ? null : _sendCode,
                    child: const Text('Send a new code'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _reviewEntries() {
    final entries = _local!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panel(
          icon: Icons.checklist_rounded,
          title: 'Choose this phone’s entries',
          body: 'Selected entries are added to the shared diary. Entries already in the cloud will be added here too. New entries sync automatically after this one-time choice.',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              '${_selected.length} of ${entries.length} selected',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton(
              onPressed: () =>
                  setState(() => _selected = {for (final m in entries) m.id}),
              child: const Text('All'),
            ),
            TextButton(
              onPressed: () => setState(() => _selected.clear()),
              child: const Text('None'),
            ),
          ],
        ),
        Card(
          child: entries.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No entries on this phone. Cloud entries will still be brought here.',
                  ),
                )
              : Column(
                  children: [
                    for (final (index, moment) in entries.indexed) ...[
                      if (index > 0) const Divider(height: 1),
                      CheckboxListTile(
                        value: _selected.contains(moment.id),
                        onChanged: _busy
                            ? null
                            : (v) => setState(
                                () => v == true
                                    ? _selected.add(moment.id)
                                    : _selected.remove(moment.id),
                              ),
                        controlAffinity: ListTileControlAffinity.leading,
                        secondary: _thumbnail(moment),
                        title: Text(
                          moment.text.isEmpty ? '(No words)' : moment.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(prettyDate(moment.createdAt)),
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _busy ? null : _finishSync,
          icon: const Icon(Icons.cloud_upload_rounded),
          label: const Text('Sync selected entries'),
        ),
      ],
    );
  }

  Widget _thumbnail(Moment moment) {
    final file = _store.file(moment.photo);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 52,
        height: 52,
        child: file.existsSync()
            ? Image.file(file, fit: BoxFit.cover)
            : const ColoredBox(
                color: Gj.sand,
                child: Icon(Icons.photo_outlined),
              ),
      ),
    );
  }

  Widget _connected() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _panel(
        icon: Icons.cloud_done_rounded,
        title: 'Sync is on',
        body:
            'Signed in as ${_account!.phoneNumber ?? _account!.displayName ?? 'your diary account'}. New entries and deletions sync through Firebase. Photos are stored with the diary.',
      ),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                await _sync.syncNow();
                if (mounted) setState(() => _busy = false);
              },
        icon: const Icon(Icons.sync_rounded),
        label: const Text('Sync now'),
      ),
      TextButton(
        onPressed: _busy ? null : _signOut,
        child: const Text('Sign out on this phone'),
      ),
    ],
  );

  Widget _panel({
    required IconData icon,
    required String title,
    required String body,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Gj.peacock, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _notice(String message, {bool isError = false}) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Text(
      message,
      style: TextStyle(
        color: isError ? Gj.kumkum : Gj.peacock,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

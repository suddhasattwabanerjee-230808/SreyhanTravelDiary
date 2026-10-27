import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../cloud_sync.dart';
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
  final _email = TextEditingController();
  final _password = TextEditingController();
  User? _account;
  List<Moment>? _local;
  Set<String> _selected = {};
  bool _register = false;
  bool _busy = false;
  bool _configured = false;
  String? _error;
  String? _message;

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
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        await _sync.createAccount(_email.text, _password.text, _name.text);
      } else {
        await _sync.signIn(_email.text, _password.text);
      }
      _account = _sync.user;
      await _prepareReview();
    } catch (e) {
      if (mounted) setState(() => _error = _authMessage(e));
    } finally {
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
        'email-already-in-use' =>
          'That email already has an account. Sign in instead.',
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' => 'The email or password is not right.',
        'weak-password' => 'Choose a password with at least 6 characters.',
        'invalid-email' => 'Enter a valid email address.',
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
        icon: Icons.cloud_sync_rounded,
        title: 'One diary on three phones',
        body: 'Use the same email and password on all three phones. Each phone gets one review to choose which of its existing entries to add.',
      ),
      const SizedBox(height: 14),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Form(
            key: _form,
            child: Column(
              children: [
                if (_register) ...[
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: "Child's name",
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Enter a name.' : null,
                  ),
                  const SizedBox(height: 10),
                ],
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => v == null || !v.contains('@')
                      ? 'Enter a valid email.'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (v) => v == null || v.length < 6
                      ? 'Use at least 6 characters.'
                      : null,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _authenticate,
                  icon: Icon(
                    _register
                        ? Icons.person_add_alt_1_rounded
                        : Icons.login_rounded,
                  ),
                  label: Text(_register ? 'Create diary account' : 'Sign in'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _register = !_register),
                  child: Text(
                    _register
                        ? 'Already set up? Sign in'
                        : 'First phone? Create your son’s account',
                  ),
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
            'Signed in as ${_account!.email ?? _account!.displayName ?? 'your diary account'}. New entries and deletions sync through Firebase. Photos are stored with the diary.',
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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'app_channel.dart';
import 'diary_store.dart';
import 'models.dart';

/// Account and continuous diary sync for the grown-ups' corner.
/// Diary data is private to the Firebase account UID. Photos live in Storage;
/// their text and metadata live in Firestore.
class CloudDiarySync {
  CloudDiarySync._();
  static final instance = CloudDiarySync._();

  DiaryStore? _store;
  StreamSubscription<User?>? _authWatch;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _remoteWatch;
  Timer? _retry;
  bool _working = false;
  String? _activeUid;
  String? _startingUid;
  final Set<String> _syncedIds = {};
  Set<String> _localOnlyIds = {};

  bool get configured => Firebase.apps.isNotEmpty;
  User? get user => configured ? FirebaseAuth.instance.currentUser : null;

  Future<void> attach(DiaryStore store) async {
    _store = store;
    if (!configured || _authWatch != null) return;
    _authWatch = FirebaseAuth.instance.authStateChanges().listen((account) {
      if (account == null) {
        _stop();
      } else {
        _startIfReady(account);
      }
    });
    final account = user;
    if (account != null) await _startIfReady(account);
  }

  /// The first OTP sign-in creates the account; the same phone number signs
  /// into that same Firebase UID on the other devices.
  Future<void> signInWithPhoneCredential(
    PhoneAuthCredential credential, {
    String childName = '',
  }) async {
    _requireFirebase();
    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    final name = childName.trim();
    if (result.additionalUserInfo?.isNewUser == true && name.isNotEmpty) {
      await result.user?.updateDisplayName(name);
    }
  }

  Future<void> signOut() async {
    if (!configured) return;
    await FirebaseAuth.instance.signOut();
  }

  Future<bool> setupComplete(User account) async =>
      (await _readState(account.uid))['complete'] == true;

  Future<List<Moment>> localMoments() async {
    final store = _store!;
    return [for (final day in await store.allDays()) ...day.moments];
  }

  Future<List<Moment>> cloudMoments(User account) async {
    final docs = await _moments(account.uid).get();
    return [for (final doc in docs.docs) Moment.fromJson(doc.data())]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// First-time setup on each phone: selected local entries join the shared
  /// diary, then existing cloud entries are brought down to this phone.
  Future<int> finishFirstSync(User account, Set<String> selectedIds) async {
    final local = await localMoments();
    final selected = [
      for (final m in local)
        if (selectedIds.contains(m.id)) m,
    ];
    _localOnlyIds = {
      for (final m in local)
        if (!selectedIds.contains(m.id)) m.id,
    };
    for (final moment in selected) {
      await _upload(account.uid, moment);
    }
    final remote = await _moments(account.uid).get();
    for (final doc in remote.docs) {
      await _mergeRemote(account.uid, doc.id, doc.data());
    }
    _syncedIds.addAll(remote.docs.map((d) => d.id));
    _syncedIds.addAll(selected.map((m) => m.id));
    await _writeState(account.uid, {
      'complete': true,
      'localOnlyIds': _localOnlyIds.toList(),
    });
    await _startIfReady(account);
    return selected.length;
  }

  /// Retry when the app returns to the foreground; uploads also retry every
  /// minute while the app is open, for entries written offline.
  Future<void> syncNow() => _flush();

  CollectionReference<Map<String, dynamic>> _moments(String uid) =>
      FirebaseFirestore.instance
          .collection('diaries')
          .doc(uid)
          .collection('moments');

  Reference _photoRef(String uid, String relativePath) =>
      FirebaseStorage.instance.ref().child('diaries/$uid/$relativePath');

  Future<void> _startIfReady(User account) async {
    final store = _store;
    if (_activeUid != null && _activeUid != account.uid) _stop();
    if (store == null) return;
    if (_activeUid == account.uid) {
      unawaited(_flush());
      return;
    }
    if (_startingUid == account.uid) return;
    _startingUid = account.uid;
    try {
      if (!await setupComplete(account)) return;
      if (_activeUid != null && _activeUid != account.uid) _stop();
      _activeUid = account.uid;
      final state = await _readState(account.uid);
      _localOnlyIds = state['localOnlyIds'] is List
          ? (state['localOnlyIds'] as List).cast<String>().toSet()
          : <String>{};
      _remoteWatch ??= _moments(account.uid).snapshots().listen(
        (snapshot) => _onRemote(account.uid, snapshot),
        onError: (Object e, StackTrace st) =>
            reportError('Diary cloud listener: $e', st),
      );
      store.addListener(_onLocalChange);
      _retry ??= Timer.periodic(const Duration(minutes: 1), (_) => _flush());
      unawaited(_flush());
    } finally {
      _startingUid = null;
    }
  }

  Future<void> _onRemote(
    String uid,
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    for (final change in snapshot.docChanges) {
      final id = change.doc.id;
      if (change.type == DocumentChangeType.removed) {
        final data = change.doc.data();
        if (data == null) {
          _syncedIds.remove(id);
          continue;
        }
        final date = data['date'] as String?;
        if (date != null) await _store?.rememberRemoteDeletion(date, id);
        _syncedIds.remove(id);
        continue;
      }
      final data = change.doc.data();
      if (data == null) continue;
      _syncedIds.add(id);
      await _mergeRemote(uid, id, data);
    }
  }

  Future<void> _mergeRemote(
    String uid,
    String id,
    Map<String, dynamic> data,
  ) async {
    final store = _store;
    if (store == null) return;
    final deleted = await store.deletedMomentIds();
    if (deleted.contains(id)) {
      await _deleteRemote(uid, id);
      return;
    }
    final incoming = Moment.fromJson(data);
    final current = await store.day(dateKey(incoming.createdAt));
    final existing = current.moments.indexWhere((m) => m.id == id);
    if (existing < 0) {
      final moments = [...current.moments, incoming]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      await store.saveDay(current.copyWith(moments: moments));
    }
    final photo = store.file(incoming.photo);
    if (!await photo.exists()) {
      try {
        final bytes = await _photoRef(
          uid,
          incoming.photo,
        ).getData(16 * 1024 * 1024);
        if (bytes != null) {
          await photo.parent.create(recursive: true);
          await photo.writeAsBytes(bytes, flush: true);
        }
      } catch (e, st) {
        reportError('Downloading diary photo ${incoming.id}: $e', st);
      }
    }
  }

  Future<void> _onLocalChange() => _flush();

  Future<void> _flush() async {
    final store = _store;
    final account = user;
    if (store == null ||
        account == null ||
        _working ||
        !await setupComplete(account)) {
      return;
    }
    _working = true;
    try {
      final deleted = await store.deletedMomentIds();
      for (final id in deleted) {
        await _deleteRemote(account.uid, id);
        await store.clearDeletedMomentId(id);
        _syncedIds.remove(id);
      }
      for (final moment in await localMoments()) {
        if (_localOnlyIds.contains(moment.id) ||
            _syncedIds.contains(moment.id)) {
          continue;
        }
        await _upload(account.uid, moment);
        _syncedIds.add(moment.id);
      }
    } catch (e, st) {
      reportError('Diary cloud sync: $e', st);
    } finally {
      _working = false;
    }
  }

  Future<void> _upload(String uid, Moment moment) async {
    final store = _store!;
    final photo = store.file(moment.photo);
    if (!await photo.exists()) {
      throw FileSystemException('The photo file is missing', photo.path);
    }
    final contentType = moment.photo.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';
    await _photoRef(
      uid,
      moment.photo,
    ).putFile(photo, SettableMetadata(contentType: contentType));
    await _moments(uid)
        .doc(moment.id)
        .set({...moment.toJson(), 'date': dateKey(moment.createdAt)});
  }

  Future<void> _deleteRemote(String uid, String id) async {
    final doc = _moments(uid).doc(id);
    final snap = await doc.get();
    if (snap.exists) {
      final path = snap.data()?['photo'] as String?;
      if (path != null) {
        try {
          await _photoRef(uid, path).delete();
        } on FirebaseException catch (e) {
          if (e.code != 'object-not-found') rethrow;
        }
      }
      await doc.delete();
    }
  }

  Future<Map<String, dynamic>> _readState(String uid) async {
    final file = _stateFile(uid);
    if (!await file.exists()) return {};
    try {
      return (jsonDecode(await file.readAsString()) as Map)
          .cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeState(String uid, Map<String, dynamic> value) async {
    final file = _stateFile(uid);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(value), flush: true);
  }

  File _stateFile(String uid) => _store!.file('sync/accounts/$uid.json');

  void _requireFirebase() {
    if (!configured) {
      throw StateError('Firebase is not configured on this build yet.');
    }
  }

  void _stop() {
    _remoteWatch?.cancel();
    _remoteWatch = null;
    _retry?.cancel();
    _retry = null;
    _syncedIds.clear();
    _localOnlyIds.clear();
    _activeUid = null;
    _startingUid = null;
    _store?.removeListener(_onLocalChange);
  }
}

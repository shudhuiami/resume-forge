import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:hive_ce/hive.dart';

import '../models/resume.dart';
import '../templates/registry.dart';

/// Storage for saved resumes.
///
/// Documents are stored as JSON strings rather than typed adapters: the schema
/// changes as templates gain fields, and a JSON blob tolerates an unknown or
/// missing key where a generated binary adapter would fail to read the box.
abstract class ResumeRepository {
  Future<List<ResumeDocument>> all();
  Future<ResumeDocument?> byId(String id);
  Future<void> save(ResumeDocument doc);
  Future<void> delete(String id);

  /// Emits the full list whenever anything changes. Drives the resume list
  /// screen without it having to poll or re-query after every edit.
  Stream<List<ResumeDocument>> watch();

  Future<void> close();
}

/// Upper bound for the random id suffix.
///
/// Deliberately 2^30 and not 2^32. On dart2js an `int` is a double and `<<` is
/// a 32-bit operation, so `1 << 32` evaluates to **0** — and `Random.nextInt(0)`
/// throws. That made resume creation fail on web while working perfectly on the
/// VM, so every widget test passed while the real app could not create a
/// document at all. Keep this comfortably inside 32 bits.
const _idSuffixBound = 1 << 30;

/// Generates a document id.
///
/// Timestamp prefix keeps ids roughly sortable by creation, which makes a
/// corrupted box easier to reason about; the random suffix prevents collisions
/// when two documents are created in the same millisecond.
String newResumeId([Random? random]) {
  final rng = random ?? Random();
  final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final suffix = rng.nextInt(_idSuffixBound).toRadixString(36).padLeft(6, '0');
  return '$stamp-$suffix';
}

/// Creates an empty document on the default template.
ResumeDocument newResumeDocument({String? templateId, String? id}) {
  final now = DateTime.now();
  return ResumeDocument(
    id: id ?? newResumeId(),
    templateId: templateId ?? defaultTemplate.id,
    createdAt: now,
    updatedAt: now,
  );
}

class HiveResumeRepository implements ResumeRepository {
  HiveResumeRepository(this._box);

  static const boxName = 'resumes';

  final Box<String> _box;
  final _changes = StreamController<List<ResumeDocument>>.broadcast();

  static Future<HiveResumeRepository> open() async {
    final box = await Hive.openBox<String>(boxName);
    return HiveResumeRepository(box);
  }

  @override
  Future<List<ResumeDocument>> all() async {
    final docs = <ResumeDocument>[];
    for (final key in _box.keys) {
      final doc = _decode(_box.get(key));
      if (doc != null) {
        docs.add(doc);
      } else {
        // A record we cannot parse is dead weight; dropping it keeps one bad
        // write from breaking the whole list screen forever.
        await _box.delete(key);
      }
    }
    docs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return docs;
  }

  @override
  Future<ResumeDocument?> byId(String id) async => _decode(_box.get(id));

  @override
  Future<void> save(ResumeDocument doc) async {
    await _box.put(doc.id, jsonEncode(doc.toJson()));
    await _emit();
  }

  @override
  Future<void> delete(String id) async {
    await _box.delete(id);
    await _emit();
  }

  @override
  Stream<List<ResumeDocument>> watch() => _changes.stream;

  Future<void> _emit() async {
    if (_changes.isClosed) return;
    _changes.add(await all());
  }

  ResumeDocument? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return ResumeDocument.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> close() async {
    await _changes.close();
    await _box.close();
  }
}

/// In-memory implementation for tests and for the first run of a widget test
/// where opening a real box would need a filesystem.
class InMemoryResumeRepository implements ResumeRepository {
  final Map<String, ResumeDocument> _store = {};
  final _changes = StreamController<List<ResumeDocument>>.broadcast();

  @override
  Future<List<ResumeDocument>> all() async {
    final docs = _store.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return docs;
  }

  @override
  Future<ResumeDocument?> byId(String id) async => _store[id];

  @override
  Future<void> save(ResumeDocument doc) async {
    // Round-trip through JSON so tests exercise the same serialization the
    // real repository does, rather than passing objects by reference.
    _store[doc.id] = ResumeDocument.fromJson(
      jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
    );
    if (!_changes.isClosed) _changes.add(await all());
  }

  @override
  Future<void> delete(String id) async {
    _store.remove(id);
    if (!_changes.isClosed) _changes.add(await all());
  }

  @override
  Stream<List<ResumeDocument>> watch() => _changes.stream;

  @override
  Future<void> close() async => _changes.close();
}

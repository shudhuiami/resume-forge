import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:resume_forge/data/resume_repository.dart';
import 'package:resume_forge/data/sample_resume.dart';
import 'package:resume_forge/models/resume.dart';

ResumeDocument docWith({
  required String id,
  required DateTime updatedAt,
  String name = '',
  String templateId = 'aurora',
  ResumeData? data,
}) {
  return ResumeDocument(
    id: id,
    templateId: templateId,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: updatedAt,
    data: data ?? ResumeData(personalInfo: PersonalInfo(fullName: name)),
  );
}

void main() {
  group('InMemoryResumeRepository', () {
    late InMemoryResumeRepository repo;

    setUp(() => repo = InMemoryResumeRepository());
    tearDown(() => repo.close());

    test('round-trips a document through save and byId', () async {
      final doc = docWith(
        id: 'a',
        updatedAt: DateTime(2024, 5, 1, 12, 30, 15, 250),
        data: sampleResume.copyWith(
          personalInfo: sampleResume.personalInfo.copyWith(
            photo: Uint8List.fromList(List<int>.generate(48, (i) => i * 5)),
          ),
        ),
      );

      await repo.save(doc);
      final restored = await repo.byId('a');

      expect(
        restored,
        equals(doc),
        reason: 'the stored copy must survive the JSON round-trip intact',
      );
      expect(
        restored!.data.personalInfo.photo,
        equals(doc.data.personalInfo.photo),
      );
      expect(restored.updatedAt, doc.updatedAt);
    });

    test('stores a copy, not the caller instance', () async {
      final doc = docWith(
        id: 'a',
        updatedAt: DateTime(2024, 5, 1),
        name: 'Ada',
      );

      await repo.save(doc);
      final restored = await repo.byId('a');

      expect(restored, equals(doc));
      expect(
        identical(restored, doc),
        isFalse,
        reason: 'a saved document must be decoupled from the caller object',
      );
    });

    test('byId returns null for an id that was never saved', () async {
      expect(await repo.byId('nope'), isNull);
    });

    test('saving the same id twice replaces rather than duplicates', () async {
      await repo.save(
        docWith(id: 'a', updatedAt: DateTime(2024, 1, 2), name: 'First'),
      );
      await repo.save(
        docWith(id: 'a', updatedAt: DateTime(2024, 1, 3), name: 'Second'),
      );

      final all = await repo.all();
      expect(all, hasLength(1));
      expect(all.single.data.personalInfo.fullName, 'Second');
    });

    test('all() returns newest-updated first', () async {
      await repo.save(
        docWith(id: 'old', updatedAt: DateTime(2024, 1, 1), name: 'Old'),
      );
      await repo.save(
        docWith(id: 'new', updatedAt: DateTime(2024, 6, 1), name: 'New'),
      );
      await repo.save(
        docWith(id: 'mid', updatedAt: DateTime(2024, 3, 1), name: 'Mid'),
      );

      expect(
        (await repo.all()).map((d) => d.id).toList(),
        ['new', 'mid', 'old'],
        reason: 'the list screen shows most recently edited first',
      );
    });

    test('delete removes only the named document', () async {
      await repo.save(docWith(id: 'a', updatedAt: DateTime(2024, 1, 1)));
      await repo.save(docWith(id: 'b', updatedAt: DateTime(2024, 1, 2)));

      await repo.delete('a');

      expect(await repo.byId('a'), isNull);
      expect(await repo.byId('b'), isNotNull);
      expect(await repo.all(), hasLength(1));
    });

    test('deleting an unknown id is a no-op', () async {
      await repo.save(docWith(id: 'a', updatedAt: DateTime(2024, 1, 1)));

      await expectLater(repo.delete('ghost'), completes);
      expect(await repo.all(), hasLength(1));
    });

    test('watch() emits after a save and after a delete', () async {
      final seen = <List<ResumeDocument>>[];
      final sub = repo.watch().listen(seen.add);
      addTearDown(sub.cancel);

      await repo.save(docWith(id: 'a', updatedAt: DateTime(2024, 1, 1)));
      await repo.save(docWith(id: 'b', updatedAt: DateTime(2024, 1, 2)));
      await repo.delete('a');
      await pumpEventQueue();

      expect(seen.map((list) => list.length).toList(), [1, 2, 1]);
      expect(seen.last.single.id, 'b');
    });

    test('watch() is a broadcast stream with room for two listeners', () async {
      final first = <int>[];
      final second = <int>[];
      final subA = repo.watch().listen((list) => first.add(list.length));
      final subB = repo.watch().listen((list) => second.add(list.length));
      addTearDown(subA.cancel);
      addTearDown(subB.cancel);

      await repo.save(docWith(id: 'a', updatedAt: DateTime(2024, 1, 1)));
      await pumpEventQueue();

      expect(first, [1]);
      expect(second, [1]);
    });

    test('close() is safe to call twice', () async {
      await repo.close();

      await expectLater(repo.close(), completes);
    });

    test('a save after close does not throw', () async {
      // Documents current behaviour: the change stream is closed but the store
      // still accepts writes, so a late autosave cannot crash the app.
      await repo.close();

      await expectLater(
        repo.save(docWith(id: 'a', updatedAt: DateTime(2024, 1, 1))),
        completes,
      );
      expect(await repo.byId('a'), isNotNull);
    });
  });

  group('HiveResumeRepository', () {
    late Directory dir;
    late Box<String> box;
    late HiveResumeRepository repo;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('resume_forge_hive');
      Hive.init(dir.path);
      box = await Hive.openBox<String>(HiveResumeRepository.boxName);
      repo = HiveResumeRepository(box);
    });

    tearDown(() async {
      await Hive.close();
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    test('round-trips a document through a real box', () async {
      final doc = docWith(
        id: 'a',
        updatedAt: DateTime(2024, 5, 1, 9, 15),
        templateId: 'ledger',
        data: sampleResume,
      );

      await repo.save(doc);

      expect(await repo.byId('a'), equals(doc));
      expect((await repo.all()).single.templateId, 'ledger');
    });

    test('survives closing and reopening the box', () async {
      final doc = docWith(
        id: 'a',
        updatedAt: DateTime(2024, 5, 1),
        name: 'Ada',
      );
      await repo.save(doc);
      await repo.close();

      final reopened = await Hive.openBox<String>(HiveResumeRepository.boxName);
      final second = HiveResumeRepository(reopened);

      expect(
        await second.byId('a'),
        equals(doc),
        reason: 'storing JSON strings must survive a process restart',
      );
    });

    test('all() returns newest-updated first', () async {
      await repo.save(docWith(id: 'old', updatedAt: DateTime(2024, 1, 1)));
      await repo.save(docWith(id: 'new', updatedAt: DateTime(2024, 6, 1)));
      await repo.save(docWith(id: 'mid', updatedAt: DateTime(2024, 3, 1)));

      expect((await repo.all()).map((d) => d.id).toList(), [
        'new',
        'mid',
        'old',
      ]);
    });

    test('drops a corrupt record instead of failing the whole list', () async {
      await repo.save(docWith(id: 'good', updatedAt: DateTime(2024, 1, 1)));
      await box.put('broken', 'this is not json at all');
      await box.put('empty', '');

      final all = await repo.all();

      expect(all.map((d) => d.id).toList(), ['good']);
      expect(
        box.containsKey('broken'),
        isFalse,
        reason:
            'a record that can never be read is purged, not re-read '
            'forever',
      );
      expect(box.containsKey('empty'), isFalse);
      expect(box.containsKey('good'), isTrue);
    });

    test('drops JSON that is well-formed but not a document', () async {
      await repo.save(docWith(id: 'good', updatedAt: DateTime(2024, 1, 1)));
      // Parses fine, but has none of the required fields.
      await box.put('wrong-shape', '{"hello":"world"}');

      final all = await repo.all();

      expect(all.map((d) => d.id).toList(), ['good']);
      expect(box.containsKey('wrong-shape'), isFalse);
    });

    test('survives a box where every record is corrupt', () async {
      await box.put('a', 'nonsense');
      await box.put('b', '[]');

      expect(await repo.all(), isEmpty);
      expect(box.isEmpty, isTrue);
    });

    test('byId returns null for a corrupt record', () async {
      await box.put('broken', '{{{');

      expect(await repo.byId('broken'), isNull);
      // Documents current behaviour: only all() prunes. A single bad read
      // leaves the record in place until the next full listing.
      expect(box.containsKey('broken'), isTrue);
    });

    test('watch() emits after a save and after a delete', () async {
      final seen = <List<ResumeDocument>>[];
      final sub = repo.watch().listen(seen.add);
      addTearDown(sub.cancel);

      await repo.save(docWith(id: 'a', updatedAt: DateTime(2024, 1, 1)));
      await repo.save(docWith(id: 'b', updatedAt: DateTime(2024, 1, 2)));
      await repo.delete('a');
      await pumpEventQueue();

      expect(seen.map((list) => list.length).toList(), [1, 2, 1]);
      expect(seen.last.single.id, 'b');
    });

    test('delete removes the record from the box', () async {
      await repo.save(docWith(id: 'a', updatedAt: DateTime(2024, 1, 1)));

      await repo.delete('a');

      expect(box.containsKey('a'), isFalse);
      expect(await repo.byId('a'), isNull);
      expect(await repo.all(), isEmpty);
    });

    test('close() is safe to call twice', () async {
      await repo.save(docWith(id: 'a', updatedAt: DateTime(2024, 1, 1)));

      await repo.close();

      await expectLater(repo.close(), completes);
    });

    test('a change after close does not emit into a closed stream', () async {
      await repo.close();

      // The stream controller is closed; emitting into it would throw.
      final reopened = await Hive.openBox<String>(HiveResumeRepository.boxName);
      final second = HiveResumeRepository(reopened);
      await expectLater(
        second.save(docWith(id: 'a', updatedAt: DateTime(2024, 1, 1))),
        completes,
      );
    });
  });

  group('newResumeDocument', () {
    test('starts on the default template with empty content', () {
      final doc = newResumeDocument();

      expect(doc.templateId, 'aurora');
      expect(doc.data.isEmpty, isTrue);
      expect(doc.createdAt, doc.updatedAt);
      expect(doc.displayTitle, 'Untitled resume');
    });

    test('honours an explicit template and id', () {
      final doc = newResumeDocument(templateId: 'terminal', id: 'fixed-id');

      expect(doc.id, 'fixed-id');
      expect(doc.templateId, 'terminal');
    });

    test('does not validate the template id it is handed', () {
      // Documents current behaviour: an unknown id is stored as-is and the
      // renderer falls back at read time via templateById.
      final doc = newResumeDocument(templateId: 'not-a-template');

      expect(doc.templateId, 'not-a-template');
    });
  });
}

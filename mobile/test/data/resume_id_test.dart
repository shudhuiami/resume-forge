import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/resume_repository.dart';

void main() {
  group('resume id generation', () {
    test('produces a usable id and never throws', () {
      // Regression: the suffix bound was 1 << 32, which is 0 on dart2js
      // because int is a double there and << is a 32-bit operation.
      // Random.nextInt(0) throws, so creating a resume failed on web while
      // every VM test passed.
      final id = newResumeId();

      expect(id, isNotEmpty);
      expect(id, contains('-'));
      expect(id.split('-'), hasLength(2));
    });

    test('is stable under repeated generation', () {
      final ids = List.generate(500, (_) => newResumeId());

      expect(
        ids.toSet().length,
        ids.length,
        reason: 'a collision would silently overwrite a saved resume',
      );
    });

    test('newResumeDocument yields a document that can be saved', () async {
      final repo = InMemoryResumeRepository();
      addTearDown(repo.close);

      final doc = newResumeDocument();
      await repo.save(doc);

      expect(await repo.byId(doc.id), isNotNull);
      expect(doc.templateId, isNotEmpty);
    });
  });
}

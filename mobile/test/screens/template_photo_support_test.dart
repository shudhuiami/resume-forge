import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/screens/gallery_screen.dart';
import 'package:resume_forge/templates/registry.dart';

/// Which designs draw a portrait, read out of the designs themselves.
///
/// Five of the thirteen render no photo at all, deliberately, and the app now
/// says so in two places: the gallery cue under every thumbnail, and a note in
/// the editor when a photo has been added to a design that will not print it
/// (QA-10). Both read [photoFreeTemplateIds], which is a *mirror* of a fact the
/// templates own.
///
/// This file is what stops the mirror going stale. The ground truth is which
/// template calls `tryDecodePhoto` — the shared decoder every design that draws
/// a portrait goes through — so that is what is derived here, from the source
/// of `lib/templates/`, rather than from a list of five names anyone has to
/// remember to update. A design that gains or loses a portrait fails this file
/// naming itself, instead of shipping with the UI quietly saying the old thing.
///
/// The cleaner home for this is a `usesPhoto` on `ResumeTemplate`, next to
/// `requiredFonts`, which would remove the source scan entirely. That is a
/// change to `lib/templates/` and is proposed rather than made here.
void main() {
  /// Every template directory, which is also the template's id.
  final directories =
      Directory('lib/templates')
          .listSync()
          .whereType<Directory>()
          .map((entry) => entry.path.split(Platform.pathSeparator).last)
          .toList(growable: false)
        ..sort();

  /// Ids whose sources never mention the shared photo decoder.
  Set<String> derivePhotoFree() {
    final photoFree = <String>{};
    for (final id in directories) {
      final sources = Directory('lib/templates/$id')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      final usesPhoto = sources.any(
        (file) => file.readAsStringSync().contains('tryDecodePhoto('),
      );
      if (!usesPhoto) photoFree.add(id);
    }
    return photoFree;
  }

  test('every template in the registry has a directory of its own', () {
    expect(
      directories.toSet(),
      resumeTemplates.map((t) => t.id).toSet(),
      reason:
          'the derivation below maps a directory to an id by name, so a design '
          'that breaks that convention would be silently skipped',
    );
  });

  test('the photo-free set is exactly the set that never decodes a photo', () {
    expect(
      photoFreeTemplateIds,
      derivePhotoFree(),
      reason:
          'a design that gained or lost a portrait left the gallery and the '
          'editor saying the opposite',
    );
  });

  test('and it is not all of them, nor none of them', () {
    // Guards the derivation itself: a scan that matched nothing — a renamed
    // helper, a moved directory — would otherwise "prove" that every design is
    // photo-free and take the assertion above with it.
    expect(photoFreeTemplateIds, isNotEmpty);
    expect(
      photoFreeTemplateIds.length,
      lessThan(resumeTemplates.length),
      reason: 'the eight designs that do draw a portrait must still do so',
    );
  });

  test('templateShowsPhoto answers for the whole registry', () {
    for (final template in resumeTemplates) {
      expect(
        templateShowsPhoto(template.id),
        !photoFreeTemplateIds.contains(template.id),
        reason: template.id,
      );
    }
  });

  /// A stored resume can name a design that no longer exists; `templateById`
  /// falls back to one that does show a photo, so the answer here has to match
  /// or the editor would put a note in front of a user about a design they are
  /// not on.
  test(
    'an unknown id answers for the design it will actually fall back to',
    () {
      expect(templateShowsPhoto('no-such-design'), isTrue);
      expect(templateShowsPhoto(templateById('no-such-design').id), isTrue);
    },
  );

  /// The gallery's own copy has to agree with the same source of truth: it is
  /// the only thing a user sees *before* choosing a design.
  group('the gallery cue', () {
    test('names the design\'s stance on a photo, either way', () {
      for (final template in resumeTemplates) {
        final cue = templateCues[template.id]!;
        expect(
          cue.contains('No photo'),
          !templateShowsPhoto(template.id),
          reason:
              '${template.id}: "$cue" does not match what the design does with '
              'a portrait',
        );
        if (templateShowsPhoto(template.id)) {
          expect(
            cue.contains('Photo'),
            isTrue,
            reason: '${template.id} draws a portrait and should advertise it',
          );
        }
      }
    });
  });
}

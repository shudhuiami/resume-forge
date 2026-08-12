import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:resume_forge/data/photo_service.dart';
import 'package:resume_forge/data/sample_portrait.dart';
import 'package:resume_forge/data/sample_resume.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/render/pdf_renderer.dart';
import 'package:resume_forge/render/truncation_check.dart';
import 'package:resume_forge/templates/registry.dart';
import 'package:resume_forge/templates/template.dart';

/// The placeholder portrait that ships inside [sampleResume].
///
/// Three separate things are pinned here, because the portrait is the only
/// binary the app *carries* rather than receives:
///
///  * it is what the generator produced — the Dart constant and the checked-in
///    JPEG cannot drift apart unnoticed, the same guard `test/brand/` puts on
///    the icon rasters;
///  * it costs what an imported photo costs, since it is stored inside the
///    resume document and that document is rewritten on every autosave;
///  * putting it in the fixture did not push anything off any of the thirteen
///    pages. That last one is the real risk: `dart_pdf`'s Column *drops* a
///    child it cannot fit rather than clipping it, so a portrait that steals
///    90pt of header can silently delete a whole section and every existing
///    test still passes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Rebuilt from the fixture rather than written out again, so this stays
  /// honest if the fixture's text changes.
  final withoutPortrait = sampleResume.copyWith(
    personalInfo: sampleResume.personalInfo.copyWith(photo: null),
  );

  group('the portrait asset', () {
    test('the Dart copy is byte-for-byte the checked-in JPEG', () {
      final onDisk = File('assets/sample/portrait.jpg').readAsBytesSync();

      expect(
        samplePortraitJpeg,
        equals(onDisk),
        reason:
            'assets/sample/portrait.jpg is the artifact a human looks at and '
            'lib/data/sample_portrait.dart is what actually ships. Both come '
            'out of assets/sample/generate_sample_portrait.py in one run; if '
            'they differ, one of them was hand-edited',
      );
    });

    test('it is a JPEG, not some other format renamed', () {
      // dart_pdf embeds a JPEG stream straight into the PDF as DCTDecode.
      // Anything else has to be re-encoded, which is both slower and larger.
      expect(samplePortraitJpeg.sublist(0, 3), equals([0xFF, 0xD8, 0xFF]));
      expect(
        img.findDecoderForData(samplePortraitJpeg),
        isA<img.JpegDecoder>(),
      );
    });

    test('it is square, at the size an imported photo is stored at', () {
      final decoded = img.decodeJpg(samplePortraitJpeg)!;

      expect(decoded.width, PhotoService.maxEdge);
      expect(decoded.height, PhotoService.maxEdge);
      expect(
        decoded.width,
        decoded.height,
        reason:
            'every template lays the portrait out in a square or circular '
            'frame with BoxFit.cover, so a non-square source would be cropped '
            'by the template instead of by the generator',
      );
    });

    test('it costs no more than a photo the user picks themselves', () {
      // The portrait lives inside the resume document, which is rewritten on
      // every autosave, which is the whole reason PhotoService downscales on
      // import. A fixture that beat that budget only by being lucky is not a
      // budget, so this is a ceiling with headroom rather than a snapshot of
      // the current byte count.
      expect(
        samplePortraitJpeg.length,
        lessThan(16 * 1024),
        reason:
            'flat tone and a smooth ground are what JPEG compresses best; a '
            'portrait that has grown past this is no longer the simple '
            'silhouette it is supposed to be',
      );

      // Re-running the import pipeline over it must not find anything left to
      // take away, which is what "already at the budget" actually means.
      final reprocessed = PhotoService.downscale(samplePortraitJpeg)!;
      expect(
        reprocessed.length,
        greaterThanOrEqualTo(samplePortraitJpeg.length - 1024),
        reason: 'it is generated at PhotoService.maxEdge and .jpegQuality',
      );
    });

    test('every template can decode it', () {
      expect(
        tryDecodePhoto(samplePortraitJpeg),
        isNotNull,
        reason:
            'tryDecodePhoto returning null is how a template decides to lay '
            'out with no portrait at all, so an undecodable fixture would fail '
            'silently as an empty slot rather than loudly',
      );
    });
  });

  group('the fixture carries it', () {
    test('sampleResume has the portrait', () {
      expect(sampleResume.personalInfo.photo, equals(samplePortraitJpeg));
    });

    test('the portrait survives the save/load round trip', () {
      final restored = ResumeData.fromJson(sampleResume.toJson());

      expect(
        restored.personalInfo.photo,
        equals(samplePortraitJpeg),
        reason:
            '"Load sample data" writes this into the user\'s own document, '
            'which is stored as JSON',
      );
    });
  });

  group('the thirteen designs', () {
    // Byte length is the signal: dart_pdf embeds the JPEG as its own object,
    // so a page that draws the portrait is about 9KB heavier than the same
    // page without it, and a page that ignores it is byte-identical.
    const rendersThePortrait = {
      'aurora',
      'beacon',
      'circuit',
      'compass',
      'coral',
      'ember',
      'meridian',
      'prism',
    };

    // Ledger, Linen, Orchid, Quill and Terminal. Three of them say so in their
    // own doc comments — an academic CV and an editorial one are a byline, not
    // a headshot — so this is the design's decision, not an oversight.
    final ignoresIt = resumeTemplates
        .map((t) => t.id)
        .where((id) => !rendersThePortrait.contains(id))
        .toSet();

    test('the split is eight to five and nothing new is missing a slot', () {
      expect(rendersThePortrait.length + ignoresIt.length, 13);
      expect(
        rendersThePortrait.every(isKnownTemplate),
        isTrue,
        reason: 'a renamed template would make this list quietly wrong',
      );
    });

    for (final template in resumeTemplates) {
      final shows = rendersThePortrait.contains(template.id);

      test(
        '"${template.id}" ${shows ? 'draws' : 'ignores'} the portrait',
        () async {
          final withPhoto = await PdfRenderer.build(
            template: template,
            data: sampleResume,
          );
          final without = await PdfRenderer.build(
            template: template,
            data: withoutPortrait,
          );

          if (shows) {
            expect(
              withPhoto.length,
              greaterThan(without.length + 4096),
              reason:
                  'this design reserves a photo slot, so the fixture must be '
                  'filling it — an equal-length render means the portrait was '
                  'dropped',
            );
          } else {
            expect(
              withPhoto.length,
              without.length,
              reason:
                  'this design has no photo slot; an embedded image it never '
                  'draws is dead weight in the exported PDF',
            );
          }
        },
      );

      test(
        '"${template.id}" loses no content to the portrait',
        () async {
          final report = await TruncationCheck.run(
            template: template,
            data: sampleResume,
          );

          expect(
            report.sections,
            isEmpty,
            reason:
                'a portrait takes vertical space out of the header, and '
                'dart_pdf deletes the child that no longer fits instead of '
                'clipping it. If this fails the fixture is advertising a design '
                'that silently drops ${report.sections.join(", ")}',
          );
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );
    }
  });
}

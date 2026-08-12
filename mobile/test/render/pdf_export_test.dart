import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/render/pdf_export.dart';

/// Stands in for the platform save dialog.
///
/// The real one is a Storage Access Framework activity; nothing about it can be
/// driven from a unit test, so the seam is here. It records what it was handed
/// so the suggested filename can be checked, and returns or throws to play back
/// each of the three things a save can do.
class _FakeSaver {
  _FakeSaver({this.location, this.error});

  /// Where the "platform" says the file landed, or null for a dismissed picker.
  final String? location;

  /// Thrown instead of returning, to play back a failed write.
  final Object? error;

  Uint8List? receivedBytes;
  String? receivedName;
  int calls = 0;

  Future<String?> call({
    required Uint8List bytes,
    required String fileName,
  }) async {
    calls++;
    receivedBytes = bytes;
    receivedName = fileName;
    if (error != null) throw error!;
    return location;
  }
}

void main() {
  String nameFor({String full = '', String title = ''}) =>
      PdfExport.fileNameFor(PersonalInfo(fullName: full, title: title));

  final samplePdf = Uint8List.fromList([37, 80, 68, 70]);
  const sampleInfo = PersonalInfo(fullName: 'Amara Okonkwo');

  group('export filename', () {
    test('slugifies the person name', () {
      expect(nameFor(full: 'Amara Okonkwo'), 'amara-okonkwo-resume.pdf');
    });

    test('strips punctuation and collapses separators', () {
      expect(
        nameFor(full: "Mary-Jane  O'Brien, Jr."),
        'mary-jane-o-brien-jr-resume.pdf',
      );
    });

    test('falls back to the job title, then to a generic name', () {
      expect(nameFor(title: 'Data Engineer'), 'data-engineer-resume.pdf');
      expect(nameFor(), 'resume.pdf');
    });

    test('handles a name with no ASCII letters at all', () {
      // Slugification can legitimately empty the string; the result must still
      // be a usable filename rather than ".pdf" or "-resume.pdf".
      expect(nameFor(full: '陳大文'), 'resume.pdf');
      expect(nameFor(full: '!!!'), 'resume.pdf');
    });

    test('does not double the resume suffix', () {
      expect(nameFor(full: 'My Resume'), 'my-resume.pdf');
    });

    test('caps absurdly long names', () {
      final long = 'Wolfeschlegelstein ' * 20;
      final result = nameFor(full: long);

      expect(result.length, lessThanOrEqualTo(72));
      expect(result, endsWith('.pdf'));
    });

    test('never emits path separators or leading dots', () {
      final result = nameFor(full: '../../etc/passwd');

      expect(result, isNot(contains('/')));
      expect(result, isNot(startsWith('.')));
      expect(result, 'etc-passwd-resume.pdf');
    });
  });

  // The share sheet is forgiving about names; a save dialog is not. These are
  // the characters that make a destination refuse the write outright, or accept
  // it under a name the user cannot find again.
  group('save filename sanitisation', () {
    test('a slash cannot open a path component', () {
      expect(nameFor(full: 'Ana / Maria'), 'ana-maria-resume.pdf');
      expect(nameFor(full: r'C:\Users\zobay'), 'c-users-zobay-resume.pdf');
    });

    test('a colon cannot survive into the name', () {
      // Illegal on every destination this app can write to, and on Android it
      // is silently rewritten, so the file lands under a name the user never
      // chose.
      expect(nameFor(full: 'Dr: Strange'), 'dr-strange-resume.pdf');
    });

    test('a trailing dot cannot survive into the name', () {
      final result = nameFor(full: 'Robert Downey Jr.');

      expect(result, 'robert-downey-jr-resume.pdf');
      expect(result, isNot(contains('..')));
      expect(result, endsWith('.pdf'));
    });

    test('a leading dot cannot make the file hidden', () {
      final result = nameFor(full: '.hidden name');

      expect(result, isNot(startsWith('.')));
      expect(result, 'hidden-name-resume.pdf');
    });

    test('control characters cannot reach the filesystem', () {
      expect(nameFor(full: 'a\u0000b\tc\nd'), 'a-b-c-d-resume.pdf');
    });

    test('does not produce a double extension', () {
      expect(nameFor(full: 'Amara.pdf'), 'amara-pdf-resume.pdf');
      expect('amara-pdf-resume.pdf'.split('.').length, 2);
    });

    test('a name of nothing but punctuation still names a file', () {
      // The slug can legitimately empty out; ".pdf" is a hidden file with no
      // name, which some pickers refuse and every user loses.
      expect(nameFor(full: '.../...'), 'resume.pdf');
      expect(nameFor(full: '   '), 'resume.pdf');
    });

    test('every awkward input still yields a legal filename', () {
      const illegal = r'/\:*?"<>|';
      for (final input in <String>[
        'Ana / Maria',
        'Dr: Strange',
        'Robert Downey Jr.',
        '.hidden',
        'a\u0000b',
        '陳大文',
        r'x*y?z"w<v>u|t',
        '../../etc/passwd',
      ]) {
        final result = nameFor(full: input);

        expect(result, endsWith('.pdf'), reason: 'for input "$input"');
        expect(result, isNot(startsWith('.')), reason: 'for input "$input"');
        expect(result.length, greaterThan('.pdf'.length));
        for (final char in illegal.split('')) {
          expect(
            result,
            isNot(contains(char)),
            reason: '"$char" is illegal in a filename, from input "$input"',
          );
        }
      }
    });

    test('the save dialog is seeded with exactly that name', () {
      // The sanitiser only helps if the picker actually gets its output.
      final saver = _FakeSaver(location: 'content://downloads/1');

      return PdfExport.save(
        pdfBytes: samplePdf,
        info: const PersonalInfo(fullName: 'Mary-Jane  O\'Brien, Jr.'),
        saver: saver.call,
      ).then((_) {
        expect(saver.receivedName, 'mary-jane-o-brien-jr-resume.pdf');
      });
    });
  });

  group('export guards', () {
    test(
      'empty bytes report a failure instead of opening a share sheet',
      () async {
        final outcome = await PdfExport.share(
          pdfBytes: Uint8List(0),
          info: const PersonalInfo(fullName: 'Amara'),
        );

        expect(outcome.status, ExportStatus.failed);
        expect(outcome.message, contains('Nothing to export'));
      },
    );

    test('empty bytes are rejected for printing too', () async {
      final outcome = await PdfExport.printDocument(
        pdfBytes: Uint8List(0),
        info: const PersonalInfo(),
      );

      expect(outcome.isFailure, isTrue);
    });
  });

  group('save to disk', () {
    test('a chosen destination is a save', () async {
      final saver = _FakeSaver(
        location: 'content://com.android.providers.downloads/document/42',
      );

      final outcome = await PdfExport.save(
        pdfBytes: samplePdf,
        info: sampleInfo,
        saver: saver.call,
      );

      expect(outcome.status, ExportStatus.saved);
      expect(outcome.isFailure, isFalse);
      expect(
        outcome.message,
        isNull,
        reason: 'a success has nothing to report',
      );
      expect(
        outcome.location,
        'content://com.android.providers.downloads/document/42',
      );
    });

    test('the exact bytes reach the picker', () async {
      final saver = _FakeSaver(location: '/tmp/x.pdf');

      await PdfExport.save(
        pdfBytes: samplePdf,
        info: sampleInfo,
        saver: saver.call,
      );

      expect(saver.calls, 1);
      expect(saver.receivedBytes, samplePdf);
      expect(saver.receivedName, 'amara-okonkwo-resume.pdf');
    });

    // The distinction the whole result vocabulary exists for: a user who backs
    // out of the picker has not hit a problem, and an error toast for changing
    // their mind is worse than silence.
    test('a dismissed picker is a cancellation, not a failure', () async {
      final saver = _FakeSaver();

      final outcome = await PdfExport.save(
        pdfBytes: samplePdf,
        info: sampleInfo,
        saver: saver.call,
      );

      expect(outcome.status, ExportStatus.dismissed);
      expect(outcome.isFailure, isFalse);
      expect(outcome.message, isNull);
      expect(outcome.location, isNull);
      expect(saver.calls, 1, reason: 'the picker did open; the user declined');
    });

    test('a failed write says what to do next', () async {
      final saver = _FakeSaver(
        error: PlatformException(
          code: 'save_file_failed',
          message: 'Failed to write to the selected document',
        ),
      );

      final outcome = await PdfExport.save(
        pdfBytes: samplePdf,
        info: sampleInfo,
        saver: saver.call,
      );

      expect(outcome.status, ExportStatus.failed);
      expect(outcome.isFailure, isTrue);
      expect(outcome.message, contains('different folder'));
    });

    test('a lost document grant does not send the user to Settings', () async {
      // A SecurityException here means the grant on the chosen document is
      // gone, not that the app lacks a permission it could go and ask for.
      final saver = _FakeSaver(
        error: PlatformException(
          code: 'security_exception',
          message: 'Permission Denial: opening provider',
        ),
      );

      final outcome = await PdfExport.save(
        pdfBytes: samplePdf,
        info: sampleInfo,
        saver: saver.call,
      );

      expect(outcome.status, ExportStatus.failed);
      expect(outcome.message, contains('no longer available'));
      expect(
        outcome.message,
        isNot(contains('Settings')),
        reason:
            'the message must not send the user hunting for a switch that '
            'does not exist',
      );
    });

    test('a second save while one is open says so', () async {
      final saver = _FakeSaver(
        error: PlatformException(
          code: 'already_active',
          message: 'File dialog is already active',
        ),
      );

      final outcome = await PdfExport.save(
        pdfBytes: samplePdf,
        info: sampleInfo,
        saver: saver.call,
      );

      expect(outcome.status, ExportStatus.failed);
      expect(outcome.message, contains('already open'));
    });

    test('a full disk names the obstacle', () async {
      final saver = _FakeSaver(
        error: StateError('ENOSPC: no space left on device'),
      );

      final outcome = await PdfExport.save(
        pdfBytes: samplePdf,
        info: sampleInfo,
        saver: saver.call,
      );

      expect(outcome.message, contains('storage space'));
    });

    test(
      'an undiagnosable failure falls back to a save-shaped message',
      () async {
        final saver = _FakeSaver(error: StateError('boom'));

        final outcome = await PdfExport.save(
          pdfBytes: samplePdf,
          info: sampleInfo,
          saver: saver.call,
        );

        expect(outcome.status, ExportStatus.failed);
        expect(outcome.message, 'Could not save the PDF.');
      },
    );

    test('empty bytes never open a picker', () async {
      final saver = _FakeSaver(location: '/tmp/x.pdf');

      final outcome = await PdfExport.save(
        pdfBytes: Uint8List(0),
        info: sampleInfo,
        saver: saver.call,
      );

      expect(outcome.status, ExportStatus.failed);
      expect(outcome.message, contains('Nothing to save'));
      expect(
        saver.calls,
        0,
        reason: 'asking for a destination for nothing wastes the user a tap',
      );
    });

    test('saving does not disturb the share vocabulary', () async {
      // Adding `saved` must not turn a dismissed share into something else.
      final outcome = await PdfExport.share(
        pdfBytes: Uint8List(0),
        info: sampleInfo,
      );

      expect(outcome.status, ExportStatus.failed);
      expect(
        ExportStatus.values,
        containsAll(<ExportStatus>[
          ExportStatus.shared,
          ExportStatus.saved,
          ExportStatus.dismissed,
          ExportStatus.failed,
        ]),
      );
    });
  });

  group('save availability', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('phones can save; desktops cannot', () {
      for (final platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.iOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(PdfExport.canSaveToDisk, isTrue, reason: '$platform');
      }
      for (final platform in <TargetPlatform>[
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(PdfExport.canSaveToDisk, isFalse, reason: '$platform');
      }
    });

    test('an unsupported platform fails before touching the channel', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      final outcome = await PdfExport.save(
        pdfBytes: samplePdf,
        info: sampleInfo,
      );

      expect(outcome.status, ExportStatus.failed);
      expect(
        outcome.message,
        contains('Share'),
        reason: 'the user still has a working way to get the PDF out',
      );
    });

    test('a missing plugin reads as unsupported, not as a crash', () async {
      final saver = _FakeSaver(
        error: MissingPluginException(
          'No implementation found for method saveFile on channel '
          'flutter_file_dialog',
        ),
      );

      final outcome = await PdfExport.save(
        pdfBytes: samplePdf,
        info: sampleInfo,
        saver: saver.call,
      );

      expect(outcome.status, ExportStatus.failed);
      expect(outcome.message, contains('not supported'));
      expect(outcome.message, isNot(contains('MissingPlugin')));
    });
  });
}

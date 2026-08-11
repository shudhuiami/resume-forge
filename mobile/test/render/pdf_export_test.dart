import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/render/pdf_export.dart';

void main() {
  String nameFor({String full = '', String title = ''}) =>
      PdfExport.fileNameFor(PersonalInfo(fullName: full, title: title));

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
}

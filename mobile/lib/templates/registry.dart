import 'aurora/aurora_template.dart';
import 'beacon/beacon_template.dart';
import 'circuit/circuit_template.dart';
import 'compass/compass_template.dart';
import 'coral/coral_template.dart';
import 'ember/ember_template.dart';
import 'ledger/ledger_template.dart';
import 'linen/linen_template.dart';
import 'meridian/meridian_template.dart';
import 'orchid/orchid_template.dart';
import 'prism/prism_template.dart';
import 'quill/quill_template.dart';
import 'terminal/terminal_template.dart';
import 'template.dart';

/// Every design in the catalog.
///
/// The single spine of the template system: the gallery, the editor, and the
/// exporter all read from this list, so adding a design is one new file plus
/// one entry here.
const List<ResumeTemplate> resumeTemplates = <ResumeTemplate>[
  AuroraTemplate(),
  MeridianTemplate(),
  BeaconTemplate(),
  LedgerTemplate(),
  CompassTemplate(),
  CircuitTemplate(),
  TerminalTemplate(),
  QuillTemplate(),
  LinenTemplate(),
  CoralTemplate(),
  OrchidTemplate(),
  PrismTemplate(),
  EmberTemplate(),
];

/// The design a new resume starts on.
ResumeTemplate get defaultTemplate => resumeTemplates.first;

/// Resolves an id to its template, falling back to [defaultTemplate].
///
/// A stored resume can name a template that no longer exists — after an
/// uninstall/downgrade, or a renamed id. Falling back keeps the user's content
/// reachable instead of failing to open the document.
ResumeTemplate templateById(String? id) {
  if (id == null) return defaultTemplate;
  for (final t in resumeTemplates) {
    if (t.id == id) return t;
  }
  return defaultTemplate;
}

/// True when [id] names a template that actually exists.
bool isKnownTemplate(String? id) =>
    id != null && resumeTemplates.any((t) => t.id == id);

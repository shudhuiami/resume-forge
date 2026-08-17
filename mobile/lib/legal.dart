/// The text of the privacy policy and the terms of use.
///
/// **These are a starting draft, not legal advice.** Every factual claim in
/// them was checked against the code — there is no network client, no analytics
/// or crash-reporting SDK, and the release manifest declares no `INTERNET`
/// permission — but whether they are *sufficient* for the jurisdictions the app
/// ships to is a question for a lawyer, not for this file.
///
/// **Three placeholders must be filled before publishing**, each marked
/// `TODO(codevioso)` below: the contact address, the governing jurisdiction,
/// and the effective date. Google Play also requires the privacy policy at a
/// public URL, so the same text has to be hosted as a web page — the in-app
/// copy does not satisfy that on its own.
///
/// Held as data rather than as widgets so the same words can be exported to a
/// web page without being retyped, and so a test can assert what they say.
library;

import 'brand.dart';

/// The day this wording took effect, as shown at the top of both documents.
///
/// TODO(codevioso): set this to the date the app is first published, and change
/// it whenever the wording changes materially.
const legalEffectiveDate = '13 August 2026';

/// Where a user can reach a human about either document.
///
/// TODO(codevioso): replace with a real, monitored address. Google Play
/// requires a support contact, and a policy that names no way to reach anyone
/// is unenforceable in the user's favour and looks abandoned.
const legalContactEmail = 'support@codevioso.com';

/// The law the terms are read under.
///
/// TODO(codevioso): confirm the jurisdiction. This should be where the
/// publishing entity is actually established.
const legalJurisdiction = 'Bangladesh';

/// One heading and the paragraphs under it.
class LegalSection {
  const LegalSection(this.heading, this.paragraphs);

  final String heading;
  final List<String> paragraphs;
}

/// A whole document: what it is called, when it took effect, what it says.
class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.summary,
    required this.sections,
  });

  final String title;

  /// The honest one-paragraph version, shown before the detail. A policy
  /// nobody reads protects nobody, so the short form comes first.
  final String summary;

  final List<LegalSection> sections;
}

/// What the app does with what you type into it.
///
/// The unusual thing about this policy is how little it has to say, and that is
/// a property of the code rather than a promise about it.
const privacyPolicy = LegalDocument(
  title: 'Privacy Policy',
  summary:
      '$appName does not collect your data. There are no accounts, no servers, '
      'no analytics and no advertising. Everything you write stays on your '
      'device, and the app has no permission to reach the internet at all.',
  sections: [
    LegalSection('What we collect', [
      'Nothing. $appName has no account system, no backend service and no '
          'analytics or crash-reporting tools. We do not receive your resume '
          'content, your name, your email address, your device identifiers or '
          'any usage statistics, because there is nowhere for that information '
          'to be sent.',
      'The Android release build declares no INTERNET permission, so the app '
          'cannot make a network request even if it tried to.',
    ]),
    LegalSection('What is stored on your device', [
      'The resumes you create — the text you type, the design you pick, and a '
          'portrait photo if you add one — are saved in the app\'s private '
          'storage on your device. Other apps cannot read that storage.',
      'These files are removed when you delete a resume inside the app, and '
          'all of them are removed when you uninstall the app.',
    ]),
    LegalSection('Camera and photo library', [
      'If you choose to add a portrait, the app asks the system for one photo — '
          'either a new one from the camera or an existing one from your '
          'library. The image is scaled down and copied into the resume on your '
          'device.',
      'The app never browses your library, never reads photos you did not pick, '
          'and never uploads any image. If you decline the permission, every '
          'other part of the app continues to work; a resume simply has no '
          'photo on it.',
    ]),
    LegalSection('Exporting a PDF', [
      'When you export, you choose what happens next: sharing the PDF hands it '
          'to an app you select, and saving it writes it to a location you pick '
          'through your device\'s own file picker.',
      'Once a PDF leaves $appName it is outside our control, and whatever you '
          'sent it to — a mail app, a messaging app, a cloud drive, a printer — '
          'handles it under that provider\'s own terms and privacy policy.',
    ]),
    LegalSection('Device backups', [
      'Android and iOS can include an app\'s data in the backup of your device, '
          'if you have device backup switched on. Where that happens, a copy of '
          'your resumes may be stored in your own Google or Apple account, '
          'under that company\'s terms — not ours. We never receive it and '
          'cannot read it.',
      'You can turn device backup off in your system settings if you would '
          'rather no copy existed anywhere but the device itself.',
    ]),
    LegalSection('Children', [
      '$appName is not directed at children, and it collects no personal '
          'information from anyone, including children.',
    ]),
    LegalSection('Changes to this policy', [
      'If this policy changes, the new version will be published with the app '
          'and the effective date above will change. Because the app collects '
          'nothing, a change here will normally mean the app gained a feature '
          'that touches your device differently — not that data started '
          'flowing somewhere.',
    ]),
    LegalSection('Contact', [
      'Questions about this policy can be sent to $legalContactEmail.',
    ]),
  ],
);

/// The agreement for using the app.
///
/// Two things are stated plainly rather than buried, because both are true and
/// a user finding them out later would rightly be annoyed: templates can drop
/// content that does not fit on one page, and no resume tool can promise you a
/// job.
const termsOfUse = LegalDocument(
  title: 'Terms of Use',
  summary:
      'Use $appName to make resumes for yourself. What you write stays yours — '
      'we never see it. The app is provided as it is, without a warranty, and '
      'it cannot promise you an interview or a job.',
  sections: [
    LegalSection('Accepting these terms', [
      'By using $appName you agree to these terms. If you do not agree with '
          'them, please do not use the app.',
    ]),
    LegalSection('Your licence to use the app', [
      'You may use $appName on any device you own, for your own personal or '
          'professional purposes, including creating resumes you are paid to '
          'write for other people.',
      'You may not sell, rent or redistribute the app itself, attempt to '
          'extract its source or its bundled designs for use in another '
          'product, or remove the credits from within it.',
    ]),
    LegalSection('Your content is yours', [
      'Everything you type into $appName, and every PDF it produces, belongs to '
          'you. We claim no ownership of it and no licence over it. We could '
          'not use it in any case: it never leaves your device.',
      'You are responsible for what you put in a resume, and for it being '
          'truthful. Do not use this app to create documents that misrepresent '
          'someone\'s identity, qualifications or history.',
    ]),
    LegalSection('What the app does not promise', [
      'The app is provided "as is", without warranties of any kind, express or '
          'implied. We do not warrant that it will be uninterrupted or '
          'error-free, or that a PDF it produces will be accepted by any '
          'particular employer, applicant tracking system or service.',
      'Resume designs lay content out on a single page. If a resume holds more '
          'than a design can fit, some content will not appear in the exported '
          'PDF. The app warns you when it detects this, both while you edit and '
          'again before you export — but you should check the preview before '
          'sending a resume anywhere that matters.',
      'Nothing in this app is career, legal, or employment advice, and using it '
          'does not make an interview or a job more likely as a matter of '
          'guarantee.',
    ]),
    LegalSection('Your data is your responsibility', [
      'Because your resumes are stored only on your device, they are lost if '
          'the device is lost, reset, or if the app is uninstalled. We hold no '
          'copy and cannot recover one for you. Export anything you would be '
          'sorry to lose.',
    ]),
    LegalSection('Limitation of liability', [
      'To the fullest extent permitted by law, $developerName is not liable for '
          'any indirect or consequential loss arising from your use of the app, '
          'including lost data, lost opportunities or lost employment.',
      'Nothing in these terms limits any right you have under consumer law that '
          'cannot be limited by agreement.',
    ]),
    LegalSection('Changes and availability', [
      'The app may change over time, and features may be added or removed. '
          'These terms may be updated with it; the effective date above will '
          'change when they are.',
    ]),
    LegalSection('Governing law', [
      'These terms are governed by the laws of $legalJurisdiction.',
    ]),
    LegalSection('Contact', [
      'Questions about these terms can be sent to $legalContactEmail.',
    ]),
  ],
);

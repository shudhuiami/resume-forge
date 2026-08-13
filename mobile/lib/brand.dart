/// The product's identity, in one place.
///
/// The app name reaches the user from four directions — the home header, the
/// About screen, the splash wordmark, the leave prompt — and before this file
/// existed it was spelled independently in two of them. A rename that misses
/// one is not a compile error; it is a screen that still says the old name.
///
/// **What is deliberately *not* here.** The Dart package is `resume_forge`,
/// the repository directory is `resume-forge`, and the application id is
/// `com.codevioso.resivo`. The first two are import paths and the third is the
/// app's identity to Android and to Play — none of them is user-visible, and
/// none of them should be derived from this string.
library;

/// What the product is called, wherever a user can read it.
const appName = 'Resivo';

/// Index of the letter the brand colours: the "i" the logo puts a gold dot on.
///
/// Held as an index into [appName] rather than as separate string literals, so
/// the name is still spelled exactly once. `test/screens/about_screen_test.dart`
/// asserts the rendered wordmark reads back as [appName], which is what keeps
/// the slicing honest.
const appNameAccentLetter = 3;

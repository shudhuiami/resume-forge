import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/theme/app_theme.dart';
import 'package:resume_forge/theme/tokens.dart';

/// WCAG 2.1 relative-contrast ratio between two opaque colours.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  const cs = AppTheme.colorScheme;

  /// Saturated accents on near-black are the classic dark-theme contrast trap,
  /// so these thresholds are asserted rather than eyeballed.
  group('WCAG AA contrast', () {
    const bodyText = 4.5;
    const largeTextAndUi = 3.0;

    void expectAtLeast(String label, Color fg, Color bg, double threshold) {
      final ratio = contrastRatio(fg, bg);
      expect(
        ratio,
        greaterThanOrEqualTo(threshold),
        reason:
            '$label contrast is ${ratio.toStringAsFixed(2)}:1, '
            'needs ${threshold.toStringAsFixed(1)}:1',
      );
    }

    test('body text on every surface tier', () {
      expectAtLeast('onSurface/surface', cs.onSurface, cs.surface, bodyText);
      expectAtLeast(
        'onSurface/surfaceContainerLow',
        cs.onSurface,
        cs.surfaceContainerLow,
        bodyText,
      );
      expectAtLeast(
        'onSurface/surfaceContainer',
        cs.onSurface,
        cs.surfaceContainer,
        bodyText,
      );
      expectAtLeast(
        'onSurface/surfaceContainerHighest',
        cs.onSurface,
        cs.surfaceContainerHighest,
        bodyText,
      );
    });

    test('muted secondary text stays readable', () {
      expectAtLeast(
        'onSurfaceVariant/surface',
        cs.onSurfaceVariant,
        cs.surface,
        bodyText,
      );
      expectAtLeast(
        'onSurfaceVariant/surfaceContainer',
        cs.onSurfaceVariant,
        cs.surfaceContainer,
        bodyText,
      );
    });

    test('filled button labels against their fills', () {
      expectAtLeast('onPrimary/primary', cs.onPrimary, cs.primary, bodyText);
      expectAtLeast(
        'onSecondary/secondary',
        cs.onSecondary,
        cs.secondary,
        bodyText,
      );
      expectAtLeast(
        'onTertiary/tertiary',
        cs.onTertiary,
        cs.tertiary,
        bodyText,
      );
      expectAtLeast('onError/error', cs.onError, cs.error, bodyText);
    });

    test('container variants', () {
      expectAtLeast(
        'onPrimaryContainer/primaryContainer',
        cs.onPrimaryContainer,
        cs.primaryContainer,
        bodyText,
      );
      expectAtLeast(
        'onSecondaryContainer/secondaryContainer',
        cs.onSecondaryContainer,
        cs.secondaryContainer,
        bodyText,
      );
      expectAtLeast(
        'onErrorContainer/errorContainer',
        cs.onErrorContainer,
        cs.errorContainer,
        bodyText,
      );
    });

    test('accent used as text (text buttons, links) on dark surfaces', () {
      expectAtLeast('primary/surface', cs.primary, cs.surface, bodyText);
      expectAtLeast(
        'primary/surfaceContainerLow',
        cs.primary,
        cs.surfaceContainerLow,
        bodyText,
      );
      expectAtLeast('error/surface', cs.error, cs.surface, bodyText);
    });

    test('non-text UI boundaries meet the 3:1 component threshold', () {
      expectAtLeast('outline/surface', cs.outline, cs.surface, largeTextAndUi);
    });
  });

  group('theme wiring', () {
    test('exposes design tokens as a theme extension', () {
      final theme = AppTheme.build();
      expect(theme.extension<AppTokens>(), isNotNull);
      expect(theme.extension<AppTokens>()!.minTouchTarget, 48);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.useMaterial3, isTrue);
    });

    test('interactive defaults meet the minimum touch target', () {
      final theme = AppTheme.build();
      final size = theme.filledButtonTheme.style?.minimumSize?.resolve({});
      expect(size?.height, greaterThanOrEqualTo(48));
    });
  });
}

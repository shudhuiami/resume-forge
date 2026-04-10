import type { CSSProperties, ReactNode } from 'react';

export type ResumePillPreset = 'xs' | 'sm' | 'md' | 'lg';

const PRESETS: Record<ResumePillPreset, { fontSizePx: number; heightPx: number; padXPx: number }> = {
  xs: { fontSizePx: 8, heightPx: 20, padXPx: 8 },
  sm: { fontSizePx: 8, heightPx: 21, padXPx: 10 },
  md: { fontSizePx: 9, heightPx: 22, padXPx: 10 },
  lg: { fontSizePx: 10, heightPx: 24, padXPx: 10 },
};

export type ResumePillOptions = {
  preset?: ResumePillPreset;
  fontSizePx?: number;
  heightPx?: number;
  padXPx?: number;
  /**
   * Uniform border width (px per side). Must match the CSS `border` width when
   * you draw a border, so `line-height` matches the content box that
   * html2canvas rasterizes.
   */
  borderWidthPx?: number;
};

/**
 * Single-line label pills safe for html2canvas/PDF: no flex alignment — the text
 * line box fills the inner height (`outerHeight - 2 * borderWidth`), same as
 * `line-height`, which browsers and canvas agree on more reliably than
 * `inline-flex` + `align-items: center`.
 */
export function resumePillStyle(opts: ResumePillOptions = {}): CSSProperties {
  const base = PRESETS[opts.preset ?? 'md'];
  const fontSizePx = opts.fontSizePx ?? base.fontSizePx;
  const heightPx = opts.heightPx ?? base.heightPx;
  const padXPx = opts.padXPx ?? base.padXPx;
  const bw = opts.borderWidthPx ?? 0;
  const innerLine = Math.max(1, heightPx - 2 * bw);

  return {
    display: 'inline-block',
    boxSizing: 'border-box',
    height: `${heightPx}px`,
    lineHeight: `${innerLine}px`,
    paddingLeft: `${padXPx}px`,
    paddingRight: `${padXPx}px`,
    paddingTop: 0,
    paddingBottom: 0,
    margin: 0,
    fontSize: `${fontSizePx}px`,
    textAlign: 'center',
    whiteSpace: 'nowrap',
    verticalAlign: 'middle',
    overflow: 'hidden',
    textOverflow: 'ellipsis',
  };
}

type ResumePillProps = ResumePillOptions & {
  style?: CSSProperties;
  children: ReactNode;
};

export function ResumePill({ style, children, ...opts }: ResumePillProps) {
  return <span style={{ ...resumePillStyle(opts), ...style }}>{children}</span>;
}

import type { CSSProperties, ReactNode } from 'react';

type SectionTitleAccentProps = {
  accentColumnPx?: number;
  columnGap?: string;
  /** Outer wrapper (e.g. h2 margins) */
  style?: CSSProperties;
  accentBarStyle: CSSProperties;
  titleStyle: CSSProperties;
  children: ReactNode;
  as?: 'div' | 'h2';
};

/**
 * Section label + left accent bar laid out with CSS grid so the bar and label
 * vertically align the same in the browser and under html2canvas/PDF (flex + raw
 * text nodes often drifts).
 */
export function SectionTitleAccent({
  accentColumnPx = 16,
  columnGap = '8px',
  style,
  accentBarStyle,
  titleStyle,
  children,
  as = 'div',
}: SectionTitleAccentProps) {
  const Tag = as;
  const tightLh = titleStyle.lineHeight ?? titleStyle.fontSize ?? 1;

  return (
    <Tag
      style={{
        display: 'grid',
        gridTemplateColumns: `${accentColumnPx}px minmax(0, 1fr)`,
        columnGap,
        alignItems: 'center',
        ...style,
      }}
    >
      <div
        style={{
          width: '100%',
          boxSizing: 'border-box',
          flexShrink: 0,
          ...accentBarStyle,
        }}
      />
      <span
        style={{
          ...titleStyle,
          margin: 0,
          display: 'block',
          lineHeight: tightLh,
        }}
      >
        {children}
      </span>
    </Tag>
  );
}

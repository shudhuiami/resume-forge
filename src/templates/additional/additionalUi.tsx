import type { CSSProperties } from 'react';
import type { CustomField, Skill } from '../../types/resume';
import { resumePillStyle } from '../resumePill';
import { SectionTitleAccent } from '../sectionLabel';

type PhotoProps = {
  photo?: string;
  name: string;
  size?: number;
  /** px corner radius, or 'full' for circle */
  rounded?: number | 'full';
  border?: string;
  initialsBg?: string;
  initialsColor?: string;
  boxShadow?: string;
};

export function PhotoOrInitials({
  photo,
  name,
  size = 100,
  rounded = 'full',
  border = '4px solid #ffffff',
  initialsBg = '#6366f1',
  initialsColor = '#ffffff',
  boxShadow,
}: PhotoProps) {
  const r = rounded === 'full' ? '50%' : `${rounded}px`;
  const base: CSSProperties = {
    width: size,
    height: size,
    borderRadius: r,
    objectFit: 'cover',
    border,
    flexShrink: 0,
    boxSizing: 'border-box',
    boxShadow,
  };
  if (photo) {
    return <img src={photo} alt="" style={base} />;
  }
  const initials = (name || 'Your Name')
    .split(/\s+/)
    .filter(Boolean)
    .map((w) => w[0])
    .join('')
    .toUpperCase()
    .slice(0, 2);
  return (
    <div
      style={{
        ...base,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        backgroundColor: initialsBg,
        color: initialsColor,
        fontWeight: 800,
        fontSize: Math.max(12, Math.round(size * 0.28)),
      }}
    >
      {initials}
    </div>
  );
}

export function SkillPillStrip({
  skills,
  bgColors,
  textColors,
  radius = 8,
}: {
  skills: Skill[];
  bgColors: string[];
  textColors: string[];
  radius?: number;
}) {
  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px' }}>
      {skills.map((s, i) => (
        <span
          key={s.id}
          style={{
            ...resumePillStyle({ preset: 'md' }),
            borderRadius: `${radius}px`,
            backgroundColor: bgColors[i % bgColors.length],
            color: textColors[i % textColors.length],
            fontWeight: 600,
          }}
        >
          {s.name}
        </span>
      ))}
    </div>
  );
}

export function CustomFieldBlocks({
  sections,
  cardBg,
  titleColor,
  accentColor,
  itemTitleColor = '#0f172a',
  itemMutedColor = '#64748b',
}: {
  sections: CustomField[];
  cardBg: string;
  titleColor: string;
  accentColor: string;
  itemTitleColor?: string;
  itemMutedColor?: string;
}) {
  const valid = sections.filter((cf) => cf.sectionTitle && cf.items.length > 0);
  if (valid.length === 0) return null;
  return (
    <>
      {valid.map((cf) => (
        <div key={cf.id} style={{ marginBottom: '16px' }}>
          <SectionTitleAccent
            accentColumnPx={14}
            columnGap="6px"
            style={{ marginBottom: '8px' }}
            accentBarStyle={{ height: 4, backgroundColor: accentColor, borderRadius: '2px' }}
            titleStyle={{
              fontSize: '10px',
              fontWeight: 700,
              letterSpacing: '0.1em',
              color: titleColor,
            }}
          >
            {cf.sectionTitle.toUpperCase()}
          </SectionTitleAccent>
          {cf.items.map((item) => (
            <div
              key={item.id}
              style={{
                marginBottom: '8px',
                padding: '8px 10px',
                backgroundColor: cardBg,
                borderRadius: '8px',
              }}
            >
              <div style={{ fontSize: '10px', fontWeight: 600, color: itemTitleColor, lineHeight: 1.25 }}>{item.title}</div>
              {item.subtitle && <div style={{ fontSize: '9px', color: accentColor, marginTop: '2px' }}>{item.subtitle}</div>}
              {item.description && <div style={{ fontSize: '9px', color: itemMutedColor, marginTop: '4px', lineHeight: 1.4 }}>{item.description}</div>}
            </div>
          ))}
        </div>
      ))}
    </>
  );
}

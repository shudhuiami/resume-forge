import type { CSSProperties } from 'react';
import { useResume } from '../../context/ResumeContext';
import { A4_HEIGHT_PX, A4_WIDTH_PX } from '../../constants/layout';
import { templateFonts } from '../fonts';
import { resumePillStyle } from '../resumePill';
import { CustomFieldBlocks, PhotoOrInitials, SkillPillStrip } from './additionalUi';

const page: CSSProperties = {
  width: A4_WIDTH_PX,
  height: A4_HEIGHT_PX,
  boxSizing: 'border-box',
  overflow: 'hidden',
};

export function PaperTemplate() {
  const { resumeData } = useResume();
  const { personalInfo, experiences, education, skills, projects, customFields } = resumeData;
  const ink = '#1e3a8a';
  const rust = '#b45309';
  return (
    <div style={{ ...page, fontFamily: templateFonts.serif, backgroundColor: '#fffef7', padding: '32px 40px', color: '#292524' }}>
      <div style={{ display: 'flex', gap: '20px', alignItems: 'flex-start', marginBottom: '20px', borderBottom: `3px double ${ink}`, paddingBottom: '18px' }}>
        <PhotoOrInitials photo={personalInfo.photo} name={personalInfo.fullName} size={88} rounded={4} border={`3px solid ${ink}`} initialsBg="#dbeafe" initialsColor={ink} />
        <div style={{ flex: 1 }}>
          <h1 style={{ fontSize: '26px', margin: 0, fontWeight: 700, color: ink, letterSpacing: '0.02em' }}>{personalInfo.fullName || 'Your Name'}</h1>
          <p style={{ fontSize: '12px', margin: '6px 0 0', fontStyle: 'italic', color: rust }}>{personalInfo.title}</p>
          <p style={{ fontSize: '9px', margin: '10px 0 0', color: '#57534e' }}>{[personalInfo.email, personalInfo.phone, personalInfo.location].filter(Boolean).join(' | ')}</p>
        </div>
      </div>
      {personalInfo.summary && (
        <p style={{ fontSize: '10px', lineHeight: 1.75, textAlign: 'justify', margin: '0 0 16px', padding: '12px 14px', backgroundColor: '#fffbeb', borderLeft: `3px solid ${rust}` }}>{personalInfo.summary}</p>
      )}
      {experiences.length > 0 && (
        <div style={{ marginBottom: '14px' }}>
          <h2 style={{ fontSize: '10px', textTransform: 'uppercase', letterSpacing: '0.25em', color: ink, margin: '0 0 10px' }}>Selected work</h2>
          {experiences.map((exp) => (
            <div key={exp.id} style={{ marginBottom: '12px', fontSize: '10px' }}>
              <strong>{exp.position}</strong>
              <span style={{ color: rust }}> · {exp.company}</span>
              <span style={{ color: '#78716c', fontSize: '9px' }}> ({exp.startDate}–{exp.current ? 'Present' : exp.endDate})</span>
              {exp.description && <div style={{ fontSize: '9px', marginTop: '4px', lineHeight: 1.55, color: '#44403c' }}>{exp.description}</div>}
            </div>
          ))}
        </div>
      )}
      <div style={{ display: 'flex', gap: '24px', fontSize: '9px' }}>
        <div style={{ flex: 1 }}>
          <strong style={{ color: ink }}>Education</strong>
          {education.map((e) => (
            <div key={e.id} style={{ marginTop: '6px' }}>
              {e.degree}, {e.institution}
            </div>
          ))}
        </div>
        <div style={{ flex: 1 }}>
          <strong style={{ color: ink }}>Expertise</strong>
          <div style={{ marginTop: '8px' }}>
            <SkillPillStrip skills={skills} bgColors={['#e0e7ff', '#ffedd5', '#fce7f3']} textColors={[ink, rust, '#9d174d']} radius={4} />
          </div>
        </div>
      </div>
      {projects.length > 0 && (
        <div style={{ marginTop: '14px', fontSize: '9px' }}>
          <strong style={{ color: ink }}>Projects</strong>
          {projects.map((p) => (
            <div key={p.id} style={{ marginTop: '6px' }}>
              {p.name} — {p.technologies}
            </div>
          ))}
        </div>
      )}
      <CustomFieldBlocks sections={customFields} cardBg="#fffbeb" titleColor={ink} accentColor={rust} />
    </div>
  );
}

export function GridTemplate() {
  const { resumeData } = useResume();
  const { personalInfo, experiences, education, skills, customFields } = resumeData;
  const colors = ['#fef3c7', '#dbeafe', '#fce7f3', '#d1fae5', '#e9d5ff'];
  return (
    <div
      style={{
        ...page,
        fontFamily: templateFonts.sans,
        backgroundColor: '#fafafa',
        backgroundImage: 'radial-gradient(#d4d4d8 1px, transparent 1px)',
        backgroundSize: '14px 14px',
        padding: '28px 32px',
      }}
    >
      <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 1fr', gap: '12px', marginBottom: '14px' }}>
        <div style={{ gridRow: 'span 2', backgroundColor: '#fff', padding: '18px', borderRadius: '16px', border: '1px solid #e4e4e7', boxShadow: '0 4px 20px rgba(0,0,0,0.06)' }}>
          <div style={{ display: 'flex', gap: '14px', alignItems: 'center' }}>
            <PhotoOrInitials photo={personalInfo.photo} name={personalInfo.fullName} size={72} rounded={14} border="3px solid #6366f1" initialsBg="#818cf8" />
            <div>
              <h1 style={{ margin: 0, fontSize: '22px', color: '#18181b', fontWeight: 800 }}>{personalInfo.fullName || 'Your Name'}</h1>
              <p style={{ margin: '4px 0 0', fontSize: '11px', color: '#6366f1', fontWeight: 600 }}>{personalInfo.title}</p>
            </div>
          </div>
          {personalInfo.summary && <p style={{ margin: '14px 0 0', fontSize: '9px', lineHeight: 1.65, color: '#52525b' }}>{personalInfo.summary}</p>}
        </div>
        <div style={{ backgroundColor: colors[0], padding: '14px', borderRadius: '12px', fontSize: '9px', color: '#713f12' }}>
          <strong>Contact</strong>
          <div style={{ marginTop: '6px', lineHeight: 1.6 }}>{personalInfo.email}</div>
        </div>
        <div style={{ backgroundColor: colors[3], padding: '14px', borderRadius: '12px', fontSize: '9px', color: '#14532d' }}>
          <strong>Education</strong>
          {education.map((e) => (
            <div key={e.id} style={{ marginTop: '6px' }}>
              {e.institution}
            </div>
          ))}
        </div>
      </div>
      {experiences.length > 0 && (
        <div style={{ backgroundColor: '#fff', padding: '16px', borderRadius: '14px', marginBottom: '12px', border: '1px solid #e4e4e7' }}>
          <div style={{ fontSize: '10px', fontWeight: 800, color: '#18181b', marginBottom: '10px' }}>Experience</div>
          {experiences.map((exp) => (
            <div key={exp.id} style={{ marginBottom: '10px', fontSize: '9px' }}>
              <strong style={{ color: '#4f46e5' }}>{exp.position}</strong> @ {exp.company}
              {exp.description && <div style={{ color: '#71717a', marginTop: '4px' }}>{exp.description}</div>}
            </div>
          ))}
        </div>
      )}
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px' }}>
        <SkillPillStrip skills={skills} bgColors={['#fef08a', '#bfdbfe', '#fbcfe8', '#bbf7d0', '#ddd6fe']} textColors={['#854d0e', '#1e40af', '#9d174d', '#166534', '#5b21b6']} />
      </div>
      <div style={{ marginTop: '12px' }}>
        <CustomFieldBlocks sections={customFields} cardBg="#f4f4f5" titleColor="#18181b" accentColor="#6366f1" />
      </div>
    </div>
  );
}

export function StripeTemplate() {
  const { resumeData } = useResume();
  const { personalInfo, experiences, education, skills, projects, customFields } = resumeData;
  const stripes = ['#7c3aed', '#6366f1', '#4f46e5', '#4338ca', '#312e81'];
  return (
    <div style={{ ...page, fontFamily: templateFonts.sans, display: 'flex', backgroundColor: '#faf5ff' }}>
      <div style={{ width: '28px', display: 'flex', flexDirection: 'column' }}>
        {stripes.map((c, i) => (
          <div key={i} style={{ flex: 1, backgroundColor: c }} />
        ))}
      </div>
      <div style={{ flex: 1, padding: '28px 32px' }}>
        <div style={{ display: 'flex', gap: '18px', marginBottom: '18px' }}>
          <PhotoOrInitials photo={personalInfo.photo} name={personalInfo.fullName} size={96} rounded={16} border="4px solid #a78bfa" initialsBg="#7c3aed" initialsColor="#fff" boxShadow="0 6px 20px rgba(124,58,237,0.35)" />
          <div>
            <h1 style={{ margin: 0, fontSize: '27px', fontWeight: 800, color: '#312e81' }}>{personalInfo.fullName || 'Your Name'}</h1>
            <p style={{ margin: '6px 0 0', color: '#7c3aed', fontWeight: 700, fontSize: '13px' }}>{personalInfo.title}</p>
            <p style={{ margin: '8px 0 0', fontSize: '10px', color: '#64748b' }}>{[personalInfo.email, personalInfo.phone, personalInfo.location].filter(Boolean).join(' · ')}</p>
          </div>
        </div>
        {personalInfo.summary && <p style={{ margin: '0 0 16px', fontSize: '10px', lineHeight: 1.65, color: '#475569', padding: '14px', backgroundColor: '#fff', borderRadius: '12px', border: '1px solid #e9d5ff' }}>{personalInfo.summary}</p>}
        {experiences.map((exp) => (
          <div key={exp.id} style={{ marginBottom: '12px', padding: '12px 14px', backgroundColor: '#fff', borderRadius: '10px', boxShadow: '0 2px 10px rgba(124,58,237,0.08)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ fontSize: '12px', fontWeight: 800, color: '#1e1b4b' }}>{exp.position}</span>
              <span
                style={{
                  ...resumePillStyle({ preset: 'xs', padXPx: 10 }),
                  color: '#fff',
                  backgroundColor: '#7c3aed',
                  borderRadius: '10px',
                }}
              >
                {exp.startDate} – {exp.current ? 'Present' : exp.endDate}
              </span>
            </div>
            <div style={{ fontSize: '10px', color: '#6d28d9', fontWeight: 600, marginTop: '4px' }}>{exp.company}</div>
            {exp.description && <p style={{ fontSize: '9px', color: '#64748b', margin: '6px 0 0' }}>{exp.description}</p>}
          </div>
        ))}
        <div style={{ fontSize: '9px', marginTop: '12px', color: '#334155' }}>
          <strong style={{ color: '#5b21b6' }}>Education:</strong> {education.map((e) => `${e.institution} (${e.degree})`).join(' · ')}
        </div>
        <div style={{ marginTop: '10px' }}>
          <SkillPillStrip skills={skills} bgColors={['#ede9fe', '#fae8ff', '#e0e7ff', '#fce7f3']} textColors={['#5b21b6', '#86198f', '#3730a3', '#9d174d']} />
        </div>
        {projects.length > 0 && (
          <div style={{ fontSize: '9px', marginTop: '10px' }}>
            <strong style={{ color: '#5b21b6' }}>Projects:</strong> {projects.map((p) => p.name).join(', ')}
          </div>
        )}
        <CustomFieldBlocks sections={customFields} cardBg="#f5f3ff" titleColor="#312e81" accentColor="#7c3aed" />
      </div>
    </div>
  );
}

export function PulseTemplate() {
  const { resumeData } = useResume();
  const { personalInfo, experiences, education, skills, projects, customFields } = resumeData;
  return (
    <div style={{ ...page, fontFamily: templateFonts.sans, background: 'linear-gradient(160deg, #fdf4ff 0%, #faf5ff 40%, #eef2ff 100%)', padding: '32px 36px' }}>
      <div style={{ textAlign: 'center', marginBottom: '22px' }}>
        <div
          style={{
            width: '112px',
            height: '112px',
            margin: '0 auto 14px',
            borderRadius: '50%',
            padding: '4px',
            background: 'linear-gradient(135deg, #e879f9, #a855f7, #6366f1)',
            boxSizing: 'border-box',
          }}
        >
          {personalInfo.photo ? (
            <img
              src={personalInfo.photo}
              alt=""
              style={{ width: '100%', height: '100%', borderRadius: '50%', objectFit: 'cover', display: 'block' }}
            />
          ) : (
            <div
              style={{
                width: '100%',
                height: '100%',
                borderRadius: '50%',
                backgroundColor: '#7c3aed',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#fff',
                fontSize: '28px',
                fontWeight: 800,
              }}
            >
              {(personalInfo.fullName || 'YL')
                .split(/\s+/)
                .filter(Boolean)
                .map((w) => w[0])
                .join('')
                .toUpperCase()
                .slice(0, 2)}
            </div>
          )}
        </div>
        <h1 style={{ margin: 0, fontSize: '26px', fontWeight: 800, color: '#581c87' }}>{personalInfo.fullName || 'Your Name'}</h1>
        <p style={{ margin: '6px 0 0', color: '#7e22ce', fontSize: '13px', fontWeight: 600 }}>{personalInfo.title}</p>
        <p style={{ margin: '8px 0 0', fontSize: '10px', color: '#6b7280' }}>{[personalInfo.email, personalInfo.location].filter(Boolean).join(' · ')}</p>
      </div>
      {personalInfo.summary && (
        <div style={{ padding: '14px 16px', borderRadius: '14px', backgroundColor: '#fff', marginBottom: '16px', fontSize: '10px', lineHeight: 1.65, color: '#4b5563', boxShadow: '0 2px 16px rgba(168,85,247,0.12)' }}>{personalInfo.summary}</div>
      )}
      {experiences.map((exp) => (
        <div key={exp.id} style={{ marginBottom: '12px', padding: '14px', backgroundColor: '#fff', borderRadius: '12px', border: '1px solid #f3e8ff' }}>
          <div style={{ fontSize: '12px', fontWeight: 800, color: '#6b21a8' }}>{exp.position}</div>
          <div style={{ fontSize: '10px', color: '#9333ea', fontWeight: 600 }}>{exp.company}</div>
          {exp.description && <p style={{ fontSize: '9px', color: '#6b7280', margin: '6px 0 0' }}>{exp.description}</p>}
        </div>
      ))}
      <div style={{ marginTop: '8px', display: 'flex', flexWrap: 'wrap', gap: '8px', justifyContent: 'center' }}>
        <SkillPillStrip skills={skills} bgColors={['#fae8ff', '#ede9fe', '#cffafe', '#fce7f3']} textColors={['#86198f', '#5b21b6', '#0e7490', '#9d174d']} radius={999} />
      </div>
      <div style={{ marginTop: '14px', fontSize: '9px', textAlign: 'center', color: '#6b7280' }}>
        {education.map((e) => (
          <span key={e.id}>
            {e.institution} · {e.degree}
            {'  '}
          </span>
        ))}
      </div>
      {projects.length > 0 && (
        <div style={{ marginTop: '12px', fontSize: '9px', textAlign: 'center', color: '#7c3aed' }}>
          {projects.map((p) => p.name).join(' · ')}
        </div>
      )}
      <CustomFieldBlocks sections={customFields} cardBg="#faf5ff" titleColor="#581c87" accentColor="#a855f7" />
    </div>
  );
}

export function SummitTemplate() {
  const { resumeData } = useResume();
  const { personalInfo, experiences, education, skills, projects, customFields } = resumeData;
  return (
    <div style={{ ...page, fontFamily: templateFonts.sans, backgroundColor: '#f1f5f9' }}>
      <div
        style={{
          height: '132px',
          background: 'linear-gradient(125deg, #0f172a 0%, #334155 40%, #0ea5e9 100%)',
          padding: '24px 36px',
          color: '#fff',
          position: 'relative',
        }}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <div>
            <h1 style={{ margin: 0, fontSize: '28px', fontWeight: 800 }}>{personalInfo.fullName || 'Your Name'}</h1>
            <p style={{ margin: '6px 0 0', fontSize: '13px', opacity: 0.95, fontWeight: 500 }}>{personalInfo.title}</p>
            <p style={{ margin: '10px 0 0', fontSize: '10px', opacity: 0.85 }}>{personalInfo.email}</p>
          </div>
          <div style={{ marginTop: '8px' }}>
            <PhotoOrInitials photo={personalInfo.photo} name={personalInfo.fullName} size={88} rounded={12} border="3px solid rgba(255,255,255,0.9)" initialsBg="#38bdf8" initialsColor="#0f172a" boxShadow="0 8px 24px rgba(0,0,0,0.25)" />
          </div>
        </div>
      </div>
      <div style={{ marginTop: '-28px', marginLeft: '32px', marginRight: '32px', backgroundColor: '#fff', borderRadius: '14px', padding: '22px', boxShadow: '0 8px 32px rgba(15,23,42,0.12)' }}>
        {personalInfo.summary && <p style={{ fontSize: '10px', lineHeight: 1.65, color: '#475569', margin: '0 0 16px' }}>{personalInfo.summary}</p>}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '18px', fontSize: '9px' }}>
          <div>
            <h3 style={{ fontSize: '10px', color: '#0f172a', margin: '0 0 10px', letterSpacing: '0.1em' }}>EXPERIENCE</h3>
            {experiences.map((exp) => (
              <div key={exp.id} style={{ marginBottom: '12px' }}>
                <strong style={{ color: '#1e293b' }}>{exp.position}</strong>
                <div style={{ color: '#64748b' }}>{exp.company}</div>
                {exp.description && <p style={{ margin: '4px 0 0', color: '#64748b', lineHeight: 1.45 }}>{exp.description}</p>}
              </div>
            ))}
          </div>
          <div>
            <h3 style={{ fontSize: '10px', color: '#0f172a', margin: '0 0 10px', letterSpacing: '0.1em' }}>EDUCATION & SKILLS</h3>
            {education.map((edu) => (
              <div key={edu.id} style={{ marginBottom: '8px', color: '#334155' }}>
                {edu.institution} — {edu.degree}
              </div>
            ))}
            <div style={{ marginTop: '10px' }}>
              <SkillPillStrip skills={skills} bgColors={['#e0f2fe', '#dbeafe', '#cffafe', '#e0e7ff']} textColors={['#0369a1', '#1d4ed8', '#0e7490', '#3730a3']} />
            </div>
            {projects.length > 0 && (
              <div style={{ marginTop: '12px' }}>
                <strong style={{ color: '#0ea5e9' }}>Projects:</strong> {projects.map((p) => p.name).join(', ')}
              </div>
            )}
          </div>
        </div>
        <div style={{ marginTop: '14px' }}>
          <CustomFieldBlocks sections={customFields} cardBg="#f8fafc" titleColor="#0f172a" accentColor="#0ea5e9" />
        </div>
      </div>
    </div>
  );
}

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

export function CrimsonTemplate() {
  const { resumeData } = useResume();
  const { personalInfo, experiences, education, skills, projects, customFields } = resumeData;
  const red = '#dc2626';
  const dark = '#450a0a';
  return (
    <div style={{ ...page, fontFamily: templateFonts.sans, backgroundColor: '#fffafa', display: 'flex' }}>
      <div style={{ width: '16px', background: `linear-gradient(180deg, ${red}, #991b1b)`, flexShrink: 0 }} />
      <div style={{ flex: 1, padding: '32px 36px' }}>
        <div style={{ display: 'flex', gap: '20px', alignItems: 'center', marginBottom: '20px' }}>
          <PhotoOrInitials photo={personalInfo.photo} name={personalInfo.fullName} size={100} rounded={16} border={`4px solid ${red}`} initialsBg="#fecaca" initialsColor={dark} />
          <div>
            <h1 style={{ margin: 0, fontSize: '28px', fontWeight: 800, color: dark }}>{personalInfo.fullName || 'Your Name'}</h1>
            <p style={{ margin: '6px 0 0', color: red, fontWeight: 700, fontSize: '13px' }}>{personalInfo.title}</p>
            <p style={{ margin: '8px 0 0', fontSize: '10px', color: '#64748b' }}>{[personalInfo.email, personalInfo.phone].filter(Boolean).join(' · ')}</p>
          </div>
        </div>
        {personalInfo.summary && (
          <div style={{ padding: '14px 16px', backgroundColor: '#fef2f2', borderRadius: '10px', borderLeft: `4px solid ${red}`, marginBottom: '20px' }}>
            <p style={{ fontSize: '10px', lineHeight: 1.65, color: '#57534e', margin: 0 }}>{personalInfo.summary}</p>
          </div>
        )}
        {experiences.length > 0 && (
          <div style={{ marginBottom: '18px' }}>
            <h2 style={{ fontSize: '10px', color: red, letterSpacing: '0.2em', margin: '0 0 12px' }}>EXPERIENCE</h2>
            {experiences.map((exp) => (
              <div key={exp.id} style={{ marginBottom: '14px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                  <strong style={{ fontSize: '12px', color: dark }}>{exp.position}</strong>
                  <span
                    style={{
                      ...resumePillStyle({ preset: 'xs', padXPx: 10 }),
                      backgroundColor: red,
                      color: '#fff',
                      borderRadius: '20px',
                    }}
                  >
                    {exp.startDate} – {exp.current ? 'Present' : exp.endDate}
                  </span>
                </div>
                <div style={{ fontSize: '10px', color: red, fontWeight: 600, marginTop: '4px' }}>{exp.company}</div>
                {exp.description && <p style={{ fontSize: '9px', color: '#64748b', margin: '6px 0 0', lineHeight: 1.5 }}>{exp.description}</p>}
              </div>
            ))}
          </div>
        )}
        <div style={{ display: 'flex', gap: '24px' }}>
          <div style={{ flex: 1 }}>
            <h2 style={{ fontSize: '10px', color: red, letterSpacing: '0.15em', margin: '0 0 10px' }}>EDUCATION</h2>
            {education.map((edu) => (
              <div key={edu.id} style={{ fontSize: '9px', marginBottom: '8px', color: '#334155' }}>
                <strong>{edu.institution}</strong> — {edu.degree}
              </div>
            ))}
          </div>
          <div style={{ flex: 1 }}>
            <h2 style={{ fontSize: '10px', color: red, letterSpacing: '0.15em', margin: '0 0 10px' }}>SKILLS</h2>
            <SkillPillStrip skills={skills} bgColors={['#fee2e2', '#fecaca', '#fecdd3', '#ffe4e6']} textColors={['#991b1b', '#b91c1c', '#9f1239', '#be123c']} />
          </div>
        </div>
        {projects.length > 0 && (
          <div style={{ marginTop: '16px' }}>
            <h2 style={{ fontSize: '10px', color: red, margin: '0 0 10px' }}>PROJECTS</h2>
            {projects.map((p) => (
              <div key={p.id} style={{ fontSize: '9px', marginBottom: '6px', padding: '8px', backgroundColor: '#fff', borderRadius: '8px', border: '1px solid #fecaca' }}>
                <strong style={{ color: dark }}>{p.name}</strong> — {p.description}
              </div>
            ))}
          </div>
        )}
        <CustomFieldBlocks sections={customFields} cardBg="#fef2f2" titleColor={dark} accentColor={red} />
      </div>
    </div>
  );
}

export function OceanTemplate() {
  const { resumeData } = useResume();
  const { personalInfo, experiences, education, skills, projects, customFields } = resumeData;
  const teal = '#0d9488';
  const aqua = '#22d3ee';
  return (
    <div style={{ ...page, fontFamily: templateFonts.sans, background: 'linear-gradient(165deg, #ccfbf1 0%, #ffffff 35%, #ecfeff 100%)' }}>
      <div style={{ padding: '28px 40px 20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h1 style={{ margin: 0, fontSize: '30px', fontWeight: 800, color: '#134e4a' }}>{personalInfo.fullName || 'Your Name'}</h1>
          <p style={{ margin: '6px 0 0', fontSize: '13px', color: teal, fontWeight: 600 }}>{personalInfo.title}</p>
          <p style={{ margin: '10px 0 0', fontSize: '10px', color: '#0f766e' }}>{personalInfo.email}</p>
        </div>
        <PhotoOrInitials photo={personalInfo.photo} name={personalInfo.fullName} size={92} rounded="full" border={`4px solid ${aqua}`} initialsBg={teal} initialsColor="#fff" />
      </div>
      <div style={{ height: '8px', margin: '0 40px', background: `linear-gradient(90deg, ${teal}, ${aqua}, #2dd4bf)`, borderRadius: '4px' }} />
      <div style={{ padding: '22px 40px 32px' }}>
        {personalInfo.summary && (
          <p style={{ fontSize: '10px', lineHeight: 1.7, color: '#134e4a', margin: '0 0 18px', padding: '14px', backgroundColor: 'rgba(255,255,255,0.85)', borderRadius: '12px', border: '1px solid #99f6e4' }}>{personalInfo.summary}</p>
        )}
        {experiences.length > 0 && (
          <div style={{ marginBottom: '18px' }}>
            {experiences.map((exp) => (
              <div key={exp.id} style={{ marginBottom: '12px', padding: '14px 16px', backgroundColor: '#fff', borderRadius: '12px', boxShadow: '0 2px 12px rgba(13,148,136,0.12)', border: '1px solid #ccfbf1' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ fontWeight: 800, fontSize: '11px', color: '#134e4a' }}>{exp.position}</span>
                  <span
                    style={{
                      ...resumePillStyle({ preset: 'xs', padXPx: 10 }),
                      color: '#fff',
                      backgroundColor: teal,
                      borderRadius: '12px',
                    }}
                  >
                    {exp.startDate} – {exp.current ? 'Present' : exp.endDate}
                  </span>
                </div>
                <div style={{ fontSize: '10px', color: '#0f766e', fontWeight: 600, marginTop: '4px' }}>{exp.company}</div>
                {exp.description && <p style={{ fontSize: '9px', color: '#475569', margin: '8px 0 0' }}>{exp.description}</p>}
              </div>
            ))}
          </div>
        )}
        <div style={{ display: 'flex', gap: '28px' }}>
          <div style={{ flex: 1 }}>
            <h3 style={{ fontSize: '10px', color: teal, margin: '0 0 10px', letterSpacing: '0.15em' }}>EDUCATION</h3>
            {education.map((edu) => (
              <div key={edu.id} style={{ fontSize: '9px', marginBottom: '8px', color: '#334155' }}>
                {edu.institution} · {edu.degree}
              </div>
            ))}
          </div>
          <div style={{ flex: 1 }}>
            <h3 style={{ fontSize: '10px', color: teal, margin: '0 0 10px', letterSpacing: '0.15em' }}>SKILLS</h3>
            <SkillPillStrip skills={skills} bgColors={['#ccfbf1', '#cffafe', '#d1fae5', '#e0f2fe']} textColors={['#115e59', '#0e7490', '#047857', '#0369a1']} />
          </div>
        </div>
        {projects.length > 0 && (
          <div style={{ marginTop: '16px' }}>
            <h3 style={{ fontSize: '10px', color: teal, margin: '0 0 8px' }}>PROJECTS</h3>
            {projects.map((p) => (
              <div key={p.id} style={{ fontSize: '9px', marginBottom: '6px' }}>
                <strong>{p.name}</strong> — {p.technologies}
              </div>
            ))}
          </div>
        )}
        <CustomFieldBlocks sections={customFields} cardBg="#f0fdfa" titleColor="#134e4a" accentColor={aqua} />
      </div>
    </div>
  );
}

export function ForestTemplate() {
  const { resumeData } = useResume();
  const { personalInfo, experiences, education, skills, projects, customFields } = resumeData;
  const leaf = '#15803d';
  const moss = '#365314';
  return (
    <div style={{ ...page, fontFamily: templateFonts.sans, backgroundColor: '#f7fee7' }}>
      <div style={{ background: `linear-gradient(90deg, ${leaf} 0%, #4d7c0f 50%, ${moss} 100%)`, padding: '24px 36px', display: 'flex', alignItems: 'center', gap: '22px', color: '#ecfccb' }}>
        <PhotoOrInitials photo={personalInfo.photo} name={personalInfo.fullName} size={88} rounded={12} border="4px solid #bbf7d0" initialsBg="#166534" initialsColor="#ecfccb" />
        <div>
          <h1 style={{ margin: 0, fontSize: '26px', fontWeight: 800 }}>{personalInfo.fullName || 'Your Name'}</h1>
          <p style={{ margin: '6px 0 0', fontSize: '13px', opacity: 0.95, fontWeight: 600 }}>{personalInfo.title}</p>
          <p style={{ margin: '8px 0 0', fontSize: '10px', opacity: 0.85 }}>{[personalInfo.email, personalInfo.phone].filter(Boolean).join(' · ')}</p>
        </div>
      </div>
      <div style={{ padding: '26px 36px 32px', color: '#14532d' }}>
        {personalInfo.summary && (
          <div style={{ padding: '14px 16px', backgroundColor: '#ecfccb', borderRadius: '10px', marginBottom: '18px', border: '1px solid #bbf7d0' }}>
            <p style={{ fontSize: '10px', lineHeight: 1.65, margin: 0 }}>{personalInfo.summary}</p>
          </div>
        )}
        {experiences.length > 0 && (
          <div style={{ marginBottom: '16px' }}>
            <h2 style={{ fontSize: '11px', color: leaf, margin: '0 0 12px', letterSpacing: '0.12em' }}>GROWTH & EXPERIENCE</h2>
            {experiences.map((exp) => (
              <div key={exp.id} style={{ marginBottom: '12px', padding: '12px 14px', paddingLeft: '16px', borderLeft: `4px solid ${leaf}`, backgroundColor: '#ffffffaa', borderRadius: '0 8px 8px 0' }}>
                <div style={{ fontSize: '12px', fontWeight: 800 }}>{exp.position}</div>
                <div style={{ fontSize: '10px', color: moss, fontWeight: 600 }}>{exp.company}</div>
                {exp.description && <p style={{ fontSize: '9px', margin: '6px 0 0', opacity: 0.9, lineHeight: 1.5 }}>{exp.description}</p>}
              </div>
            ))}
          </div>
        )}
        <div style={{ display: 'flex', gap: '28px' }}>
          <div>
            <strong style={{ color: leaf }}>Education</strong>
            {education.map((edu) => (
              <div key={edu.id} style={{ marginTop: '8px', fontSize: '9px' }}>
                {edu.institution} — {edu.degree}
              </div>
            ))}
          </div>
          <div style={{ flex: 1 }}>
            <strong style={{ color: leaf }}>Skills</strong>
            <div style={{ marginTop: '8px' }}>
              <SkillPillStrip skills={skills} bgColors={['#d9f99d', '#bbf7d0', '#a7f3d0', '#fde68a']} textColors={['#3f6212', '#14532d', '#047857', '#a16207']} />
            </div>
          </div>
        </div>
        {projects.length > 0 && (
          <div style={{ marginTop: '16px', fontSize: '9px' }}>
            <strong style={{ color: moss }}>Projects</strong>
            {projects.map((p) => (
              <div key={p.id} style={{ marginTop: '6px' }}>
                {p.name}: {p.description}
              </div>
            ))}
          </div>
        )}
        <CustomFieldBlocks sections={customFields} cardBg="#ecfccb" titleColor={moss} accentColor={leaf} />
      </div>
    </div>
  );
}

export function SunsetTemplate() {
  const { resumeData } = useResume();
  const { personalInfo, experiences, education, skills, customFields } = resumeData;
  return (
    <div style={{ ...page, fontFamily: templateFonts.sans, backgroundColor: '#fff7ed' }}>
      <div
        style={{
          padding: '28px 36px',
          background: 'linear-gradient(120deg, #fb923c 0%, #f472b6 45%, #a855f7 100%)',
          color: '#fff',
          display: 'flex',
          alignItems: 'center',
          gap: '22px',
        }}
      >
        <PhotoOrInitials photo={personalInfo.photo} name={personalInfo.fullName} size={96} rounded={20} border="4px solid rgba(255,255,255,0.9)" initialsBg="#ffffff33" initialsColor="#fff" />
        <div>
          <h1 style={{ margin: 0, fontSize: '28px', fontWeight: 800, textShadow: '0 2px 8px rgba(0,0,0,0.15)' }}>{personalInfo.fullName || 'Your Name'}</h1>
          <p style={{ margin: '6px 0 0', fontSize: '13px', fontWeight: 600, opacity: 0.95 }}>{personalInfo.title}</p>
          <p style={{ margin: '8px 0 0', fontSize: '10px', opacity: 0.9 }}>{personalInfo.email}</p>
        </div>
      </div>
      <div style={{ padding: '26px 36px', color: '#7c2d12' }}>
        {personalInfo.summary && <p style={{ fontSize: '10px', lineHeight: 1.7, margin: '0 0 18px', padding: '14px', backgroundColor: '#ffedd5', borderRadius: '12px' }}>{personalInfo.summary}</p>}
        {experiences.map((exp) => (
          <div key={exp.id} style={{ marginBottom: '14px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
              <div>
                <div style={{ fontSize: '12px', fontWeight: 800 }}>{exp.position}</div>
                <div style={{ fontSize: '10px', color: '#c2410c', fontWeight: 600 }}>{exp.company}</div>
              </div>
              <span
                style={{
                  ...resumePillStyle({ preset: 'xs', padXPx: 10 }),
                  backgroundColor: '#fdba74',
                  color: '#7c2d12',
                  borderRadius: '12px',
                }}
              >
                {exp.startDate} – {exp.current ? 'Present' : exp.endDate}
              </span>
            </div>
            {exp.description && <p style={{ fontSize: '9px', margin: '6px 0 0', color: '#78716c' }}>{exp.description}</p>}
          </div>
        ))}
        <div style={{ marginTop: '8px' }}>
          <SkillPillStrip skills={skills} bgColors={['#ffedd5', '#fce7f3', '#e9d5ff', '#fef3c7']} textColors={['#9a3412', '#9d174d', '#6b21a8', '#a16207']} radius={20} />
        </div>
        <div style={{ marginTop: '14px', fontSize: '9px', color: '#57534e' }}>
          <strong>Education:</strong> {education.map((e) => `${e.institution} (${e.degree})`).join(' · ')}
        </div>
        <div style={{ marginTop: '12px' }}>
          <CustomFieldBlocks sections={customFields} cardBg="#fff7ed" titleColor="#7c2d12" accentColor="#ea580c" />
        </div>
      </div>
    </div>
  );
}

export function NoirTemplate() {
  const { resumeData } = useResume();
  const { personalInfo, experiences, education, skills, projects, customFields } = resumeData;
  const gold = '#d4af37';
  return (
    <div style={{ ...page, fontFamily: templateFonts.serif, background: 'radial-gradient(ellipse at top, #1c1917 0%, #0c0a09 100%)', color: '#e7e5e4', padding: '36px 40px' }}>
      <div style={{ display: 'flex', gap: '24px', marginBottom: '24px', paddingBottom: '22px', borderBottom: `1px solid ${gold}44` }}>
        <PhotoOrInitials photo={personalInfo.photo} name={personalInfo.fullName} size={108} rounded={4} border={`3px solid ${gold}`} initialsBg="#292524" initialsColor={gold} />
        <div style={{ flex: 1 }}>
          <h1 style={{ margin: 0, fontSize: '32px', fontWeight: 300, letterSpacing: '0.12em', color: '#fafaf9' }}>{(personalInfo.fullName || 'Your Name').toUpperCase()}</h1>
          <p style={{ margin: '10px 0 0', fontSize: '12px', color: gold, fontStyle: 'italic' }}>{personalInfo.title}</p>
          <p style={{ margin: '10px 0 0', fontSize: '10px', color: '#a8a29e' }}>{[personalInfo.email, personalInfo.location].filter(Boolean).join(' · ')}</p>
        </div>
      </div>
      {personalInfo.summary && <p style={{ fontSize: '10px', lineHeight: 1.75, color: '#d6d3d1', margin: '0 0 22px', fontStyle: 'italic' }}>{personalInfo.summary}</p>}
      {experiences.length > 0 && (
        <div style={{ marginBottom: '20px' }}>
          {experiences.map((exp) => (
            <div key={exp.id} style={{ marginBottom: '18px', paddingLeft: '14px', borderLeft: `2px solid ${gold}` }}>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span style={{ fontSize: '11px', fontWeight: 700, color: '#fafaf9' }}>{exp.position}</span>
                <span style={{ fontSize: '9px', color: gold }}>{exp.startDate}</span>
              </div>
              <div style={{ fontSize: '10px', color: '#a8a29e', marginTop: '4px' }}>{exp.company}</div>
              {exp.description && <p style={{ fontSize: '9px', color: '#a8a29e', margin: '8px 0 0', lineHeight: 1.55 }}>{exp.description}</p>}
            </div>
          ))}
        </div>
      )}
      <div style={{ fontSize: '9px', color: '#a8a29e', lineHeight: 1.75 }}>
        <div>
          <strong style={{ color: gold }}>Education</strong> — {education.map((e) => e.institution).join('; ')}
        </div>
        <div style={{ marginTop: '12px' }}>
          <strong style={{ color: gold }}>Skills</strong> —{' '}
          <span style={{ color: '#e7e5e4' }}>{skills.map((s) => s.name).join(' · ')}</span>
        </div>
        {projects.length > 0 && (
          <div style={{ marginTop: '12px' }}>
            <strong style={{ color: gold }}>Projects</strong> — {projects.map((p) => p.name).join(', ')}
          </div>
        )}
      </div>
      <div style={{ marginTop: '16px' }}>
        <CustomFieldBlocks
          sections={customFields}
          cardBg="#1c1917"
          titleColor={gold}
          accentColor="#f59e0b"
          itemTitleColor="#fafaf9"
          itemMutedColor="#a8a29e"
        />
      </div>
    </div>
  );
}

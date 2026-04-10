import type { CSSProperties } from 'react';
import { useResume } from '../../context/ResumeContext';
import { A4_HEIGHT_PX, A4_WIDTH_PX } from '../../constants/layout';
import { templateFonts } from '../fonts';
import { resumePillStyle } from '../resumePill';
import { SectionTitleAccent } from '../sectionLabel';
import { CustomFieldBlocks, PhotoOrInitials, SkillPillStrip } from './additionalUi';

const page: CSSProperties = {
  width: A4_WIDTH_PX,
  height: A4_HEIGHT_PX,
  boxSizing: 'border-box',
  overflow: 'hidden',
};

export function AtlasTemplate() {
  const { resumeData } = useResume();
  const { personalInfo, experiences, education, skills, projects, customFields } = resumeData;
  const navy = '#0c1929';
  const coral = '#fb7185';
  const mint = '#5eead4';
  return (
    <div style={{ ...page, fontFamily: templateFonts.sans, backgroundColor: '#f8fafc', position: 'relative' }}>
      <div
        style={{
          position: 'absolute',
          top: 0,
          right: 0,
          width: '280px',
          height: '180px',
          background: `linear-gradient(135deg, ${coral}33 0%, ${mint}44 100%)`,
          borderRadius: '0 0 0 120px',
        }}
      />
      <div style={{ position: 'relative', zIndex: 1, padding: '28px 32px 0' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '22px' }}>
          <PhotoOrInitials photo={personalInfo.photo} name={personalInfo.fullName} size={108} rounded={20} border={`4px solid ${navy}`} initialsBg={coral} />
          <div style={{ flex: 1 }}>
            <h1 style={{ margin: 0, fontSize: '28px', fontWeight: 800, color: navy, letterSpacing: '-0.02em' }}>{personalInfo.fullName || 'Your Name'}</h1>
            <p style={{ margin: '6px 0 0', fontSize: '13px', color: coral, fontWeight: 600 }}>{personalInfo.title}</p>
            <div style={{ marginTop: '10px', display: 'flex', flexWrap: 'wrap', gap: '8px', fontSize: '9px', color: '#475569' }}>
              {personalInfo.email && (
                <span
                  style={{
                    ...resumePillStyle({ fontSizePx: 9, heightPx: 24, padXPx: 10, borderWidthPx: 1 }),
                    backgroundColor: '#fff',
                    borderRadius: '20px',
                    border: `1px solid ${mint}66`,
                  }}
                >
                  {personalInfo.email}
                </span>
              )}
              {personalInfo.phone && (
                <span
                  style={{
                    ...resumePillStyle({ fontSizePx: 9, heightPx: 24, padXPx: 10, borderWidthPx: 1 }),
                    backgroundColor: '#fff',
                    borderRadius: '20px',
                    border: `1px solid ${coral}55`,
                  }}
                >
                  {personalInfo.phone}
                </span>
              )}
              {personalInfo.location && (
                <span
                  style={{
                    ...resumePillStyle({ fontSizePx: 9, heightPx: 24, padXPx: 10, borderWidthPx: 1 }),
                    backgroundColor: '#fff',
                    borderRadius: '20px',
                    border: `1px solid #cbd5e1`,
                  }}
                >
                  {personalInfo.location}
                </span>
              )}
            </div>
          </div>
        </div>
      </div>
      <div style={{ display: 'flex', padding: '22px 32px 28px', gap: '24px', position: 'relative', zIndex: 1 }}>
        <div style={{ flex: 1 }}>
          {personalInfo.summary && (
            <section style={{ marginBottom: '18px', padding: '14px 16px', backgroundColor: '#fff', borderRadius: '12px', border: `1px solid #e2e8f0`, boxShadow: '0 2px 12px rgba(15,23,42,0.06)' }}>
              <h2 style={{ fontSize: '10px', color: navy, letterSpacing: '0.15em', margin: '0 0 8px' }}>ABOUT</h2>
              <p style={{ fontSize: '10px', lineHeight: 1.65, color: '#334155', margin: 0 }}>{personalInfo.summary}</p>
            </section>
          )}
          {experiences.length > 0 && (
            <section>
              <SectionTitleAccent
                as="h2"
                accentColumnPx={20}
                style={{ margin: '0 0 12px' }}
                accentBarStyle={{
                  height: 4,
                  borderRadius: '2px',
                  background: `linear-gradient(90deg, ${coral}, ${mint})`,
                }}
                titleStyle={{ fontSize: '10px', color: navy, letterSpacing: '0.15em', fontWeight: 700 }}
              >
                EXPERIENCE
              </SectionTitleAccent>
              {experiences.map((exp) => (
                <div key={exp.id} style={{ marginBottom: '14px', paddingLeft: '12px', borderLeft: `3px solid ${coral}` }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                    <div>
                      <div style={{ fontSize: '12px', fontWeight: 700, color: navy }}>{exp.position}</div>
                      <div style={{ fontSize: '10px', color: coral, fontWeight: 600 }}>{exp.company}</div>
                    </div>
                    <span
                      style={{
                        ...resumePillStyle({ preset: 'xs', padXPx: 8 }),
                        backgroundColor: `${mint}33`,
                        color: '#0f766e',
                        borderRadius: '8px',
                      }}
                    >
                      {exp.startDate} – {exp.current ? 'Present' : exp.endDate}
                    </span>
                  </div>
                  {exp.description && <p style={{ fontSize: '9px', color: '#64748b', margin: '6px 0 0', lineHeight: 1.55 }}>{exp.description}</p>}
                </div>
              ))}
            </section>
          )}
          {projects.length > 0 && (
            <section style={{ marginTop: '16px' }}>
              <h2 style={{ fontSize: '10px', color: navy, letterSpacing: '0.15em', margin: '0 0 10px' }}>PROJECTS</h2>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '10px' }}>
                {projects.map((p, i) => (
                  <div key={p.id} style={{ width: 'calc(50% - 5px)', padding: '10px', backgroundColor: i % 2 === 0 ? '#fff1f2' : '#f0fdfa', borderRadius: '10px', border: '1px solid #e2e8f0' }}>
                    <div style={{ fontSize: '10px', fontWeight: 700, color: navy }}>{p.name}</div>
                    {p.technologies && <div style={{ fontSize: '8px', color: coral, marginTop: '4px' }}>{p.technologies}</div>}
                    {p.description && <div style={{ fontSize: '8px', color: '#64748b', marginTop: '4px', lineHeight: 1.45 }}>{p.description}</div>}
                  </div>
                ))}
              </div>
            </section>
          )}
        </div>
        <div style={{ width: '210px', flexShrink: 0 }}>
          {skills.length > 0 && (
            <section style={{ marginBottom: '16px' }}>
              <h2 style={{ fontSize: '10px', color: navy, letterSpacing: '0.15em', margin: '0 0 10px' }}>SKILLS</h2>
              <SkillPillStrip skills={skills} bgColors={['#ffe4e6', '#e0f2fe', '#f3e8ff', '#ecfccb', '#fef3c7']} textColors={['#be123c', '#0369a1', '#7c3aed', '#3f6212', '#b45309']} />
            </section>
          )}
          {education.map((edu) => (
            <section key={edu.id} style={{ marginBottom: '14px', padding: '12px', backgroundColor: '#fff', borderRadius: '10px', border: `1px solid ${mint}55` }}>
              <h2 style={{ fontSize: '9px', color: mint, letterSpacing: '0.12em', margin: '0 0 6px' }}>EDUCATION</h2>
              <div style={{ fontSize: '10px', fontWeight: 700, color: navy }}>{edu.degree}</div>
              <div style={{ fontSize: '9px', color: '#64748b', marginTop: '4px' }}>{edu.institution}</div>
              <div style={{ fontSize: '8px', color: '#94a3b8', marginTop: '4px' }}>
                {edu.startDate} – {edu.endDate}
              </div>
            </section>
          ))}
          <CustomFieldBlocks sections={customFields} cardBg="#f1f5f9" titleColor={navy} accentColor={coral} />
        </div>
      </div>
    </div>
  );
}

export function HorizonTemplate() {
  const { resumeData } = useResume();
  const { personalInfo, experiences, education, skills, projects, customFields } = resumeData;
  const sky = '#0ea5e9';
  const indigo = '#4f46e5';
  const rose = '#f43f5e';
  return (
    <div style={{ ...page, fontFamily: templateFonts.sans, background: 'linear-gradient(180deg, #ecfeff 0%, #ffffff 45%, #faf5ff 100%)' }}>
      <div style={{ padding: '32px 36px 20px', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <div style={{ flex: 1, paddingRight: '16px' }}>
          <h1 style={{ margin: 0, fontSize: '30px', fontWeight: 800, color: '#0f172a', lineHeight: 1.1 }}>{personalInfo.fullName || 'Your Name'}</h1>
          <p style={{ margin: '8px 0 0', fontSize: '13px', fontWeight: 600, color: indigo }}>{personalInfo.title}</p>
          <p style={{ margin: '10px 0 0', fontSize: '10px', color: '#64748b' }}>{[personalInfo.email, personalInfo.phone, personalInfo.location].filter(Boolean).join('  ·  ')}</p>
        </div>
        <PhotoOrInitials photo={personalInfo.photo} name={personalInfo.fullName} size={96} rounded="full" border={`4px solid ${sky}`} initialsBg={indigo} boxShadow="0 8px 24px rgba(79,70,229,0.35)" />
      </div>
      {personalInfo.summary && (
        <div style={{ margin: '0 36px 20px', padding: '14px 18px', backgroundColor: '#fff', borderRadius: '14px', borderLeft: `4px solid ${sky}`, boxShadow: '0 2px 16px rgba(14,165,233,0.12)' }}>
          <p style={{ fontSize: '10px', lineHeight: 1.7, color: '#475569', margin: 0, fontStyle: 'italic' }}>{personalInfo.summary}</p>
        </div>
      )}
      <div style={{ padding: '0 36px', display: 'flex', gap: '24px' }}>
        <div style={{ width: '200px', flexShrink: 0 }}>
          {skills.length > 0 && (
            <div style={{ marginBottom: '18px' }}>
              <div style={{ fontSize: '10px', fontWeight: 700, color: rose, marginBottom: '10px', letterSpacing: '0.12em' }}>SKILLS</div>
              <SkillPillStrip skills={skills} bgColors={['#ffe4e6', '#e0e7ff', '#cffafe', '#fef9c3', '#dcfce7']} textColors={['#be123c', '#3730a3', '#0e7490', '#a16207', '#166534']} radius={20} />
            </div>
          )}
          {education.map((edu) => (
            <div key={edu.id} style={{ marginBottom: '12px', padding: '10px 12px', backgroundColor: '#fff', borderRadius: '10px', boxShadow: '0 1px 8px rgba(0,0,0,0.05)' }}>
              <div style={{ fontSize: '10px', fontWeight: 700, color: '#0f172a' }}>{edu.institution}</div>
              <div style={{ fontSize: '9px', color: indigo, marginTop: '2px' }}>{edu.degree}</div>
              <div style={{ fontSize: '8px', color: '#94a3b8', marginTop: '4px' }}>
                {edu.startDate} – {edu.endDate}
              </div>
            </div>
          ))}
          <CustomFieldBlocks sections={customFields} cardBg="#f8fafc" titleColor="#0f172a" accentColor={sky} />
        </div>
        <div style={{ flex: 1 }}>
          {experiences.length > 0 && (
            <div style={{ marginBottom: '16px' }}>
              <div style={{ fontSize: '10px', fontWeight: 700, color: sky, marginBottom: '12px', letterSpacing: '0.12em' }}>TIMELINE</div>
              {experiences.map((exp, i) => (
                <div key={exp.id} style={{ display: 'flex', gap: '12px', marginBottom: i === experiences.length - 1 ? 0 : '16px' }}>
                  <div style={{ width: '56px', flexShrink: 0, fontSize: '8px', color: '#94a3b8', textAlign: 'right', paddingTop: '4px' }}>{exp.startDate}</div>
                  <div style={{ flex: 1, paddingLeft: '14px', borderLeft: `3px solid ${i % 2 === 0 ? sky : indigo}`, position: 'relative' }}>
                    <div style={{ position: 'absolute', left: '-7px', top: '6px', width: '10px', height: '10px', borderRadius: '50%', backgroundColor: i % 2 === 0 ? sky : indigo }} />
                    <div style={{ fontSize: '12px', fontWeight: 700, color: '#0f172a' }}>{exp.position}</div>
                    <div style={{ fontSize: '10px', color: indigo, fontWeight: 600 }}>{exp.company}</div>
                    {exp.description && <p style={{ fontSize: '9px', color: '#64748b', margin: '6px 0 0', lineHeight: 1.5 }}>{exp.description}</p>}
                  </div>
                </div>
              ))}
            </div>
          )}
          {projects.length > 0 && (
            <div>
              <div style={{ fontSize: '10px', fontWeight: 700, color: indigo, marginBottom: '10px' }}>PROJECTS</div>
              {projects.map((p) => (
                <div key={p.id} style={{ marginBottom: '10px', padding: '10px 12px', backgroundColor: '#eef2ff', borderRadius: '8px' }}>
                  <div style={{ fontSize: '10px', fontWeight: 700 }}>{p.name}</div>
                  <div style={{ fontSize: '8px', color: indigo }}>{p.technologies}</div>
                  {p.description && <div style={{ fontSize: '8px', color: '#64748b', marginTop: '4px' }}>{p.description}</div>}
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export function MonoTemplate() {
  const { resumeData } = useResume();
  const { personalInfo, experiences, education, skills, projects, customFields } = resumeData;
  const bg = '#0c0c0f';
  const green = '#4ade80';
  const pink = '#f472b6';
  return (
    <div style={{ ...page, fontFamily: templateFonts.mono, backgroundColor: bg, color: green, padding: '28px 32px' }}>
      <div style={{ display: 'flex', gap: '20px', marginBottom: '20px', border: `1px solid ${green}44`, borderRadius: '8px', padding: '16px', backgroundColor: '#111118' }}>
        <PhotoOrInitials photo={personalInfo.photo} name={personalInfo.fullName} size={88} rounded={8} border={`2px solid ${green}`} initialsBg="#1e1e2e" initialsColor={pink} />
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: '10px', color: pink, marginBottom: '6px' }}>{'>'} profile.json</div>
          <div style={{ fontSize: '14px', fontWeight: 700, color: '#f8fafc' }}>{personalInfo.fullName || 'Your Name'}</div>
          <div style={{ fontSize: '10px', color: green, marginTop: '4px' }}>{personalInfo.title}</div>
          <div style={{ fontSize: '8px', color: '#94a3b8', marginTop: '8px', lineHeight: 1.6 }}>
            {personalInfo.email && <div>email: {personalInfo.email}</div>}
            {personalInfo.phone && <div>phone: {personalInfo.phone}</div>}
            {personalInfo.location && <div>location: {personalInfo.location}</div>}
          </div>
        </div>
      </div>
      {personalInfo.summary && (
        <div style={{ marginBottom: '16px', padding: '12px', backgroundColor: '#111118', borderRadius: '6px', border: `1px dashed ${green}55`, fontSize: '9px', lineHeight: 1.6, color: '#cbd5e1' }}>
          <span style={{ color: pink }}>// summary</span>
          <br />
          {personalInfo.summary}
        </div>
      )}
      {experiences.length > 0 && (
        <div style={{ marginBottom: '14px' }}>
          <div style={{ fontSize: '9px', color: pink, marginBottom: '8px' }}>{'>'} experience.log</div>
          {experiences.map((exp) => (
            <div key={exp.id} style={{ marginBottom: '12px', paddingLeft: '10px', borderLeft: `2px solid ${green}66` }}>
              <div style={{ fontSize: '10px', color: '#f8fafc' }}>
                {exp.position} @ {exp.company}
              </div>
              <div style={{ fontSize: '8px', color: green }}>[{exp.startDate} → {exp.current ? 'now' : exp.endDate}]</div>
              {exp.description && <div style={{ fontSize: '8px', color: '#94a3b8', marginTop: '4px' }}>{exp.description}</div>}
            </div>
          ))}
        </div>
      )}
      <div style={{ display: 'flex', gap: '20px', fontSize: '8px' }}>
        <div style={{ flex: 1 }}>
          <div style={{ color: pink, marginBottom: '6px' }}>{'>'} education</div>
          {education.map((edu) => (
            <div key={edu.id} style={{ marginBottom: '6px', color: '#e2e8f0' }}>
              {edu.institution}: {edu.degree}
            </div>
          ))}
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ color: pink, marginBottom: '6px' }}>{'>'} skills[]</div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '4px' }}>
            {skills.map((s) => (
              <span
                key={s.id}
                style={{
                  ...resumePillStyle({ preset: 'xs', padXPx: 8, borderWidthPx: 1 }),
                  backgroundColor: '#1e293b',
                  border: `1px solid ${green}44`,
                  borderRadius: '4px',
                  color: green,
                }}
              >
                {s.name}
              </span>
            ))}
          </div>
        </div>
      </div>
      {projects.length > 0 && (
        <div style={{ marginTop: '14px', fontSize: '8px' }}>
          <div style={{ color: pink, marginBottom: '6px' }}>{'>'} projects</div>
          {projects.map((p) => (
            <div key={p.id} style={{ marginBottom: '4px', color: '#cbd5e1' }}>
              {p.name} — {p.technologies}
            </div>
          ))}
        </div>
      )}
      <div style={{ marginTop: '12px' }}>
        <CustomFieldBlocks
          sections={customFields}
          cardBg="#111118"
          titleColor={green}
          accentColor={pink}
          itemTitleColor="#f8fafc"
          itemMutedColor="#94a3b8"
        />
      </div>
    </div>
  );
}

export function SlateTemplate() {
  const { resumeData } = useResume();
  const { personalInfo, experiences, education, skills, projects, customFields } = resumeData;
  const deep = '#312e81';
  const lilac = '#c4b5fd';
  const amber = '#fbbf24';
  return (
    <div style={{ ...page, fontFamily: templateFonts.sans, display: 'flex', flexDirection: 'row-reverse', backgroundColor: '#faf5ff' }}>
      <div style={{ width: '248px', background: `linear-gradient(180deg, ${deep} 0%, #1e1b4b 100%)`, color: '#f5f3ff', padding: '28px 20px' }}>
        <PhotoOrInitials photo={personalInfo.photo} name={personalInfo.fullName} size={112} rounded="full" border={`4px solid ${amber}`} initialsBg="#6366f1" boxShadow="0 4px 20px rgba(0,0,0,0.3)" />
        <h1 style={{ fontSize: '20px', margin: '18px 0 6px', fontWeight: 800, lineHeight: 1.2 }}>{personalInfo.fullName || 'Your Name'}</h1>
        <p style={{ fontSize: '11px', color: lilac, margin: 0, fontWeight: 500 }}>{personalInfo.title}</p>
        <div style={{ marginTop: '20px', fontSize: '9px', lineHeight: 1.85, color: '#c7d2fe' }}>
          {personalInfo.email && <div>{personalInfo.email}</div>}
          {personalInfo.phone && <div>{personalInfo.phone}</div>}
          {personalInfo.location && <div>{personalInfo.location}</div>}
        </div>
        {skills.length > 0 && (
          <div style={{ marginTop: '22px' }}>
            <div style={{ fontSize: '9px', letterSpacing: '0.2em', color: amber, marginBottom: '10px' }}>SKILLS</div>
            <SkillPillStrip skills={skills} bgColors={['#4338ca', '#5b21b6', '#6d28d9']} textColors={['#fef3c7', '#e9d5ff', '#fce7f3']} radius={6} />
          </div>
        )}
        {education.map((edu) => (
          <div key={edu.id} style={{ marginTop: '18px', padding: '10px', backgroundColor: '#ffffff18', borderRadius: '8px', fontSize: '9px' }}>
            <div style={{ fontWeight: 700, color: '#fff' }}>{edu.institution}</div>
            <div style={{ color: lilac, marginTop: '4px' }}>{edu.degree}</div>
          </div>
        ))}
        <CustomFieldBlocks
          sections={customFields}
          cardBg="#ffffff22"
          titleColor="#fef3c7"
          accentColor={amber}
          itemTitleColor="#ffffff"
          itemMutedColor="#c7d2fe"
        />
      </div>
      <div style={{ flex: 1, padding: '28px 26px', color: '#1e1b4b' }}>
        {personalInfo.summary && (
          <p style={{ fontSize: '10px', lineHeight: 1.7, margin: '0 0 20px', padding: '14px', backgroundColor: '#fff', borderRadius: '12px', border: `1px solid ${lilac}66` }}>{personalInfo.summary}</p>
        )}
        {experiences.length > 0 && (
          <div>
            <h2 style={{ fontSize: '11px', color: deep, margin: '0 0 12px', letterSpacing: '0.1em' }}>EXPERIENCE</h2>
            {experiences.map((exp) => (
              <div key={exp.id} style={{ marginBottom: '14px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ fontSize: '12px', fontWeight: 700 }}>{exp.position}</span>
                  <span
                    style={{
                      ...resumePillStyle({ preset: 'xs' }),
                      color: '#6b7280',
                      backgroundColor: '#ede9fe',
                      borderRadius: '8px',
                    }}
                  >
                    {exp.startDate} – {exp.current ? 'Present' : exp.endDate}
                  </span>
                </div>
                <div style={{ fontSize: '10px', color: '#5b21b6', fontWeight: 600 }}>{exp.company}</div>
                {exp.description && <p style={{ fontSize: '9px', color: '#64748b', margin: '6px 0 0', lineHeight: 1.5 }}>{exp.description}</p>}
              </div>
            ))}
          </div>
        )}
        {projects.length > 0 && (
          <div style={{ marginTop: '16px' }}>
            <h2 style={{ fontSize: '11px', color: deep, margin: '0 0 10px' }}>PROJECTS</h2>
            {projects.map((p) => (
              <div key={p.id} style={{ marginBottom: '8px', fontSize: '9px' }}>
                <strong>{p.name}</strong> — <span style={{ color: '#6b7280' }}>{p.description}</span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

export function IvoryTemplate() {
  const { resumeData } = useResume();
  const { personalInfo, experiences, education, skills, projects, customFields } = resumeData;
  const gold = '#b45309';
  const wine = '#7f1d1d';
  return (
    <div style={{ ...page, fontFamily: templateFonts.serif, backgroundColor: '#fffbeb', color: '#422006', padding: '36px 44px' }}>
      <div style={{ textAlign: 'center', marginBottom: '24px' }}>
        <PhotoOrInitials photo={personalInfo.photo} name={personalInfo.fullName} size={104} rounded="full" border={`5px double ${gold}`} initialsBg="#fef3c7" initialsColor={wine} />
        <h1 style={{ fontSize: '30px', fontWeight: 400, margin: '16px 0 6px', color: wine, letterSpacing: '0.04em' }}>{personalInfo.fullName || 'Your Name'}</h1>
        <p style={{ fontSize: '12px', fontStyle: 'italic', margin: 0, color: gold }}>{personalInfo.title}</p>
        <p style={{ fontSize: '10px', margin: '12px 0 0', color: '#78716c' }}>{[personalInfo.email, personalInfo.phone, personalInfo.location].filter(Boolean).join('  ·  ')}</p>
      </div>
      {personalInfo.summary && (
        <div style={{ maxWidth: '640px', margin: '0 auto 22px', padding: '16px 20px', backgroundColor: '#fff7ed', borderRadius: '4px', border: `1px solid ${gold}44` }}>
          <p style={{ fontSize: '10px', lineHeight: 1.8, textAlign: 'center', margin: 0, fontStyle: 'italic', color: '#57534e' }}>{personalInfo.summary}</p>
        </div>
      )}
      {experiences.length > 0 && (
        <div style={{ marginBottom: '20px' }}>
          <h2 style={{ fontSize: '11px', textTransform: 'uppercase', letterSpacing: '0.25em', color: gold, margin: '0 0 14px', textAlign: 'center' }}>
            Experience
          </h2>
          {experiences.map((exp) => (
            <div key={exp.id} style={{ marginBottom: '14px', paddingBottom: '12px', borderBottom: `1px solid ${gold}33` }}>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span style={{ fontSize: '11px', fontWeight: 700, color: wine }}>{exp.position}</span>
                <span style={{ fontSize: '9px', color: '#a8a29e' }}>
                  {exp.startDate} – {exp.current ? 'Present' : exp.endDate}
                </span>
              </div>
              <div style={{ fontSize: '10px', color: gold, fontWeight: 600, marginTop: '2px' }}>{exp.company}</div>
              {exp.description && <p style={{ fontSize: '9px', margin: '6px 0 0', lineHeight: 1.6, color: '#57534e' }}>{exp.description}</p>}
            </div>
          ))}
        </div>
      )}
      <div style={{ display: 'flex', gap: '36px' }}>
        <div style={{ flex: 1 }}>
          <h2 style={{ fontSize: '11px', textTransform: 'uppercase', letterSpacing: '0.2em', color: gold, margin: '0 0 10px' }}>Education</h2>
          {education.map((edu) => (
            <div key={edu.id} style={{ fontSize: '10px', marginBottom: '10px' }}>
              <strong>{edu.institution}</strong>
              <div style={{ color: '#78716c', marginTop: '2px' }}>{edu.degree}</div>
            </div>
          ))}
        </div>
        <div style={{ flex: 1 }}>
          <h2 style={{ fontSize: '11px', textTransform: 'uppercase', letterSpacing: '0.2em', color: gold, margin: '0 0 10px' }}>Skills</h2>
          <SkillPillStrip skills={skills} bgColors={['#ffedd5', '#fecaca', '#fde68a', '#d9f99d', '#e9d5ff']} textColors={['#9a3412', '#991b1b', '#a16207', '#3f6212', '#6b21a8']} />
        </div>
      </div>
      {projects.length > 0 && (
        <div style={{ marginTop: '20px' }}>
          <h2 style={{ fontSize: '11px', textTransform: 'uppercase', letterSpacing: '0.2em', color: gold, margin: '0 0 10px' }}>Projects</h2>
          {projects.map((p) => (
            <div key={p.id} style={{ fontSize: '9px', marginBottom: '6px' }}>
              <strong style={{ color: wine }}>{p.name}</strong> — {p.technologies}
            </div>
          ))}
        </div>
      )}
      <div style={{ marginTop: '16px' }}>
        <CustomFieldBlocks sections={customFields} cardBg="#fff7ed" titleColor={wine} accentColor={gold} />
      </div>
    </div>
  );
}

import { useResume } from '../../context/ResumeContext';
import { templateFonts } from '../fonts';
import { resumePillStyle } from '../resumePill';

export function TechTemplate() {
  const { resumeData } = useResume();
  const { personalInfo, experiences, education, skills, projects, customFields } = resumeData;
  const validCustomFields = customFields.filter((cf) => cf.sectionTitle && cf.items.length > 0);
  const fonts = templateFonts;

  return (
    <div
      style={{
        width: '794px',
        height: '1123px',
        backgroundColor: '#0f172a',
        fontFamily: fonts.tech,
        color: '#e2e8f0',
        overflow: 'hidden',
      }}
    >
      <div style={{ padding: '36px 40px', borderBottom: '1px solid #334155', display: 'flex', alignItems: 'center', gap: '24px' }}>
        {personalInfo.photo && (
          <img
            src={personalInfo.photo}
            alt=""
            style={{
              width: '90px',
              height: '90px',
              borderRadius: '10px',
              objectFit: 'cover',
              objectPosition: 'center',
              border: '3px solid #06b6d4',
              flexShrink: 0,
            }}
          />
        )}
        <div style={{ flex: 1 }}>
          <h1 style={{ fontSize: '26px', fontWeight: 700, color: '#ffffff', margin: '0 0 4px 0', lineHeight: '1.2' }}>{personalInfo.fullName || 'Your Name'}</h1>
          <p style={{ fontSize: '13px', color: '#06b6d4', margin: 0 }}>{personalInfo.title || 'Professional Title'}</p>
        </div>
        <div style={{ fontSize: '9px', color: '#94a3b8', lineHeight: '2', textAlign: 'right' }}>
          {personalInfo.email && (
            <div>
              <span style={{ color: '#06b6d4' }}>email:</span> {personalInfo.email}
            </div>
          )}
          {personalInfo.phone && (
            <div>
              <span style={{ color: '#06b6d4' }}>phone:</span> {personalInfo.phone}
            </div>
          )}
          {personalInfo.location && (
            <div>
              <span style={{ color: '#06b6d4' }}>location:</span> {personalInfo.location}
            </div>
          )}
          {personalInfo.website && (
            <div>
              <span style={{ color: '#06b6d4' }}>web:</span> {personalInfo.website}
            </div>
          )}
        </div>
      </div>
      <div style={{ padding: '28px 40px', display: 'flex', gap: '32px' }}>
        <div style={{ width: '200px', flexShrink: 0 }}>
          {skills.length > 0 && (
            <div style={{ marginBottom: '24px' }}>
              <h2 style={{ fontSize: '10px', fontWeight: 700, color: '#06b6d4', margin: '0 0 12px 0', letterSpacing: '1px' }}>{'<'} TECH_STACK {'>'}</h2>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px' }}>
                {skills.map((skill) => (
                  <span
                    key={skill.id}
                    style={{
                      ...resumePillStyle({ fontSizePx: 9, heightPx: 24, padXPx: 8, borderWidthPx: 1 }),
                      backgroundColor: '#1e293b',
                      border: '1px solid #334155',
                      borderRadius: '4px',
                      color: '#94a3b8',
                    }}
                  >
                    {skill.name}
                  </span>
                ))}
              </div>
            </div>
          )}
          {education.length > 0 && (
            <div style={{ marginBottom: '24px' }}>
              <h2 style={{ fontSize: '10px', fontWeight: 700, color: '#06b6d4', margin: '0 0 12px 0', letterSpacing: '1px' }}>{'<'} EDUCATION {'>'}</h2>
              {education.map((edu, index) => (
                <div
                  key={edu.id}
                  style={{
                    marginBottom: index === education.length - 1 ? 0 : '12px',
                    padding: '10px',
                    backgroundColor: '#1e293b',
                    borderRadius: '6px',
                    borderLeft: '3px solid #06b6d4',
                  }}
                >
                  <div style={{ fontSize: '10px', fontWeight: 600, color: '#f1f5f9', margin: 0 }}>{edu.degree}</div>
                  <div style={{ fontSize: '9px', color: '#94a3b8', marginTop: '3px' }}>{edu.institution}</div>
                  <div style={{ fontSize: '8px', color: '#64748b', marginTop: '4px' }}>
                    {edu.startDate} - {edu.endDate}
                  </div>
                </div>
              ))}
            </div>
          )}
          {validCustomFields.map((cf) => (
            <div key={cf.id} style={{ marginBottom: '24px' }}>
              <h2 style={{ fontSize: '10px', fontWeight: 700, color: '#06b6d4', margin: '0 0 12px 0', letterSpacing: '1px' }}>
                {'<'}{' '}
                {cf.sectionTitle.toUpperCase().replace(/ /g, '_')} {' '}
                {'>'}
              </h2>
              {cf.items.map((item, idx) => (
                <div
                  key={item.id}
                  style={{
                    marginBottom: idx === cf.items.length - 1 ? 0 : '8px',
                    padding: '8px 10px',
                    backgroundColor: '#1e293b',
                    borderRadius: '4px',
                    borderLeft: '2px solid #334155',
                  }}
                >
                  <div style={{ fontSize: '9px', fontWeight: 600, color: '#e2e8f0', lineHeight: 1.25 }}>{item.title}</div>
                  {item.subtitle && <div style={{ fontSize: '8px', color: '#06b6d4', marginTop: '4px', lineHeight: 1.25 }}>{item.subtitle}</div>}
                  {item.description && <div style={{ fontSize: '8px', color: '#64748b', marginTop: '4px', lineHeight: 1.35 }}>{item.description}</div>}
                </div>
              ))}
            </div>
          ))}
        </div>
        <div style={{ flex: 1 }}>
          {personalInfo.summary && (
            <div style={{ marginBottom: '24px', padding: '14px', backgroundColor: '#1e293b', borderRadius: '8px' }}>
              <div style={{ fontSize: '9px', color: '#06b6d4', marginBottom: '8px' }}>{'// about_me'}</div>
              <p style={{ fontSize: '10px', lineHeight: '1.7', color: '#cbd5e1', margin: 0 }}>{personalInfo.summary}</p>
            </div>
          )}
          {experiences.length > 0 && (
            <div style={{ marginBottom: '24px' }}>
              <h2 style={{ fontSize: '10px', fontWeight: 700, color: '#06b6d4', margin: '0 0 12px 0', letterSpacing: '1px' }}>{'<'} EXPERIENCE {'>'}</h2>
              {experiences.map((exp, index) => (
                <div key={exp.id} style={{ marginBottom: index === experiences.length - 1 ? 0 : '12px', padding: '14px', backgroundColor: '#1e293b', borderRadius: '8px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                    <div>
                      <h3 style={{ fontSize: '12px', fontWeight: 600, color: '#f1f5f9', margin: 0 }}>{exp.position}</h3>
                      <p style={{ fontSize: '10px', color: '#06b6d4', margin: '3px 0 0 0' }}>{exp.company}</p>
                    </div>
                    <span
                      style={{
                        ...resumePillStyle({ preset: 'xs' }),
                        color: '#64748b',
                        backgroundColor: '#0f172a',
                        borderRadius: '4px',
                      }}
                    >
                      {exp.startDate} → {exp.current ? 'present' : exp.endDate}
                    </span>
                  </div>
                  {exp.description && <p style={{ fontSize: '9px', color: '#94a3b8', marginTop: '10px', lineHeight: '1.6', margin: '10px 0 0 0' }}>{exp.description}</p>}
                </div>
              ))}
            </div>
          )}
          {projects.length > 0 && (
            <div>
              <h2 style={{ fontSize: '10px', fontWeight: 700, color: '#06b6d4', margin: '0 0 12px 0', letterSpacing: '1px' }}>{'<'} PROJECTS {'>'}</h2>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '10px' }}>
                {projects.map((project) => (
                  <div
                    key={project.id}
                    style={{
                      width: 'calc(50% - 5px)',
                      padding: '12px',
                      backgroundColor: '#1e293b',
                      borderRadius: '8px',
                      border: '1px solid #334155',
                    }}
                  >
                    <h3 style={{ fontSize: '10px', fontWeight: 600, color: '#f1f5f9', margin: 0 }}>{project.name}</h3>
                    {project.technologies && <p style={{ fontSize: '8px', color: '#06b6d4', margin: '4px 0 0 0' }}>[{project.technologies}]</p>}
                    {project.description && <p style={{ fontSize: '8px', color: '#94a3b8', marginTop: '6px', lineHeight: '1.5', margin: '6px 0 0 0' }}>{project.description}</p>}
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

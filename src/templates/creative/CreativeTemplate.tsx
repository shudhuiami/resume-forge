import { useResume } from '../../context/ResumeContext';
import { templateFonts } from '../fonts';
import { resumePillStyle } from '../resumePill';
import { SectionTitleAccent } from '../sectionLabel';

export function CreativeTemplate() {
  const { resumeData } = useResume();
  const { personalInfo, experiences, education, skills, projects, customFields } = resumeData;
  const validCustomFields = customFields.filter((cf) => cf.sectionTitle && cf.items.length > 0);
  const fonts = templateFonts;

  return (
    <div
      style={{
        width: '794px',
        height: '1123px',
        backgroundColor: '#fefefe',
        fontFamily: fonts.creative,
        overflow: 'hidden',
        position: 'relative',
      }}
    >
      <div
        style={{
          position: 'absolute',
          top: 0,
          right: 0,
          width: '200px',
          height: '200px',
          background: 'linear-gradient(135deg, #fce7f3 0%, #ddd6fe 100%)',
          borderRadius: '0 0 0 200px',
          opacity: 0.6,
        }}
      />
      <div
        style={{
          position: 'absolute',
          bottom: 0,
          left: 0,
          width: '150px',
          height: '150px',
          background: 'linear-gradient(45deg, #e0f2fe 0%, #fce7f3 100%)',
          borderRadius: '0 150px 0 0',
          opacity: 0.5,
        }}
      />

      <div style={{ padding: '40px 44px 32px 44px', position: 'relative', zIndex: 1 }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: '28px' }}>
          {personalInfo.photo && (
            <div style={{ position: 'relative' }}>
              <div
                style={{
                  position: 'absolute',
                  top: '-6px',
                  left: '-6px',
                  width: '108px',
                  height: '108px',
                  borderRadius: '20px',
                  background: 'linear-gradient(135deg, #f472b6 0%, #a78bfa 50%, #60a5fa 100%)',
                  transform: 'rotate(3deg)',
                }}
              />
              <img
                src={personalInfo.photo}
                alt=""
                style={{
                  width: '96px',
                  height: '96px',
                  borderRadius: '16px',
                  objectFit: 'cover',
                  objectPosition: 'center',
                  position: 'relative',
                  zIndex: 1,
                  border: '3px solid #ffffff',
                }}
              />
            </div>
          )}
          <div style={{ flex: 1 }}>
            {/* Solid fill — html2canvas does not match browser for background-clip: text */}
            <h1
              style={{
                fontSize: '32px',
                fontWeight: 800,
                margin: '0 0 6px 0',
                lineHeight: 1.15,
                color: '#9333ea',
                letterSpacing: '-0.02em',
              }}
            >
              {personalInfo.fullName || 'Your Name'}
            </h1>
            <p style={{ fontSize: '15px', color: '#6b7280', fontWeight: 500, margin: '0 0 12px 0', letterSpacing: '0.5px' }}>
              {personalInfo.title || 'Professional Title'}
            </p>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '12px', fontSize: '10px', color: '#6b7280' }}>
              {personalInfo.email && (
                <span
                  style={{
                    ...resumePillStyle({ preset: 'lg' }),
                    backgroundColor: '#fdf2f8',
                    borderRadius: '20px',
                    color: '#be185d',
                  }}
                >
                  {personalInfo.email}
                </span>
              )}
              {personalInfo.phone && (
                <span
                  style={{
                    ...resumePillStyle({ preset: 'lg' }),
                    backgroundColor: '#f3e8ff',
                    borderRadius: '20px',
                    color: '#7c3aed',
                  }}
                >
                  {personalInfo.phone}
                </span>
              )}
              {personalInfo.location && (
                <span
                  style={{
                    ...resumePillStyle({ preset: 'lg' }),
                    backgroundColor: '#e0f2fe',
                    borderRadius: '20px',
                    color: '#0369a1',
                  }}
                >
                  {personalInfo.location}
                </span>
              )}
            </div>
          </div>
        </div>
      </div>

      {personalInfo.summary && (
        <div style={{ padding: '0 44px', marginBottom: '24px', position: 'relative', zIndex: 1 }}>
          <div
            style={{
              padding: '16px 20px',
              backgroundColor: '#faf5ff',
              borderRadius: '12px',
              border: '1px solid #f3e8ff',
            }}
          >
            <p style={{ fontSize: '11px', lineHeight: 1.75, color: '#4b5563', margin: 0, fontStyle: 'italic' }}>&quot;{personalInfo.summary}&quot;</p>
          </div>
        </div>
      )}

      <div style={{ padding: '0 44px', display: 'flex', gap: '32px', position: 'relative', zIndex: 1 }}>
        <div style={{ width: '200px', flexShrink: 0 }}>
          {skills.length > 0 && (
            <div style={{ marginBottom: '24px' }}>
              <SectionTitleAccent
                as="h2"
                style={{ margin: '0 0 12px 0' }}
                accentBarStyle={{
                  height: 4,
                  borderRadius: '2px',
                  background: 'linear-gradient(90deg, #ec4899, #8b5cf6)',
                }}
                titleStyle={{
                  fontSize: '11px',
                  fontWeight: 700,
                  color: '#ec4899',
                  letterSpacing: '1px',
                  textTransform: 'uppercase',
                }}
              >
                Skills
              </SectionTitleAccent>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px' }}>
                {skills.map((skill, idx) => {
                  const colors = ['#fdf2f8', '#faf5ff', '#eff6ff', '#f0fdf4', '#fefce8'];
                  const textColors = ['#be185d', '#7c3aed', '#1d4ed8', '#15803d', '#a16207'];
                  return (
                    <span
                      key={skill.id}
                      style={{
                        ...resumePillStyle({ preset: 'md' }),
                        backgroundColor: colors[idx % 5],
                        borderRadius: '8px',
                        color: textColors[idx % 5],
                        fontWeight: 600,
                      }}
                    >
                      {skill.name}
                    </span>
                  );
                })}
              </div>
            </div>
          )}

          {education.length > 0 && (
            <div style={{ marginBottom: '24px' }}>
              <SectionTitleAccent
                as="h2"
                style={{ margin: '0 0 12px 0' }}
                accentBarStyle={{
                  height: 4,
                  borderRadius: '2px',
                  background: 'linear-gradient(90deg, #8b5cf6, #3b82f6)',
                }}
                titleStyle={{
                  fontSize: '11px',
                  fontWeight: 700,
                  color: '#8b5cf6',
                  letterSpacing: '1px',
                  textTransform: 'uppercase',
                }}
              >
                Education
              </SectionTitleAccent>
              {education.map((edu, index) => (
                <div key={edu.id} style={{ marginBottom: index === education.length - 1 ? 0 : '14px', padding: '12px', backgroundColor: '#faf5ff', borderRadius: '10px' }}>
                  <div style={{ fontSize: '11px', fontWeight: 700, color: '#1f2937', margin: 0 }}>{edu.degree}</div>
                  {edu.field && <div style={{ fontSize: '9px', color: '#8b5cf6', marginTop: '2px', fontWeight: 500 }}>{edu.field}</div>}
                  <div style={{ fontSize: '10px', color: '#6b7280', marginTop: '4px' }}>{edu.institution}</div>
                  <div style={{ fontSize: '9px', color: '#9ca3af', marginTop: '3px' }}>
                    {edu.startDate} - {edu.endDate}
                  </div>
                </div>
              ))}
            </div>
          )}

          {validCustomFields.map((cf) => (
            <div key={cf.id} style={{ marginBottom: '24px' }}>
              <SectionTitleAccent
                as="h2"
                style={{ margin: '0 0 12px 0' }}
                accentBarStyle={{
                  height: 4,
                  borderRadius: '2px',
                  background: 'linear-gradient(90deg, #3b82f6, #06b6d4)',
                }}
                titleStyle={{
                  fontSize: '11px',
                  fontWeight: 700,
                  color: '#3b82f6',
                  letterSpacing: '1px',
                  textTransform: 'uppercase',
                }}
              >
                {cf.sectionTitle}
              </SectionTitleAccent>
              {cf.items.map((item, idx) => (
                <div
                  key={item.id}
                  style={{
                    marginBottom: idx === cf.items.length - 1 ? 0 : '10px',
                    padding: '8px 10px',
                    backgroundColor: '#eff6ff',
                    borderRadius: '8px',
                  }}
                >
                  <div style={{ fontSize: '10px', fontWeight: 600, color: '#1f2937', lineHeight: 1.25 }}>{item.title}</div>
                  {item.subtitle && <div style={{ fontSize: '9px', color: '#3b82f6', marginTop: '2px' }}>{item.subtitle}</div>}
                  {item.description && <div style={{ fontSize: '9px', color: '#6b7280', marginTop: '2px' }}>{item.description}</div>}
                </div>
              ))}
            </div>
          ))}
        </div>

        <div style={{ flex: 1 }}>
          {experiences.length > 0 && (
            <div style={{ marginBottom: '24px' }}>
              <SectionTitleAccent
                as="h2"
                style={{ margin: '0 0 14px 0' }}
                accentBarStyle={{
                  height: 4,
                  borderRadius: '2px',
                  background: 'linear-gradient(90deg, #ec4899, #f472b6)',
                }}
                titleStyle={{
                  fontSize: '11px',
                  fontWeight: 700,
                  color: '#ec4899',
                  letterSpacing: '1px',
                  textTransform: 'uppercase',
                }}
              >
                Experience
              </SectionTitleAccent>
              {experiences.map((exp, index) => (
                <div key={exp.id} style={{ marginBottom: index === experiences.length - 1 ? 0 : '16px', position: 'relative', paddingLeft: '16px' }}>
                  <div style={{ position: 'absolute', left: 0, top: '6px', width: '6px', height: '6px', borderRadius: '50%', backgroundColor: '#db2777' }} />
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '4px' }}>
                    <div>
                      <h3 style={{ fontSize: '13px', fontWeight: 700, color: '#1f2937', margin: 0 }}>{exp.position}</h3>
                      <p style={{ fontSize: '11px', color: '#8b5cf6', margin: '2px 0 0 0', fontWeight: 500 }}>{exp.company}</p>
                    </div>
                    <span
                      style={{
                        ...resumePillStyle({ preset: 'md' }),
                        color: '#ffffff',
                        backgroundColor: '#c026d3',
                        borderRadius: '12px',
                        fontWeight: 500,
                      }}
                    >
                      {exp.startDate} - {exp.current ? 'Present' : exp.endDate}
                    </span>
                  </div>
                  {exp.description && <p style={{ fontSize: '10px', color: '#6b7280', marginTop: '8px', lineHeight: '1.6', margin: '8px 0 0 0' }}>{exp.description}</p>}
                </div>
              ))}
            </div>
          )}

          {projects.length > 0 && (
            <div>
              <SectionTitleAccent
                as="h2"
                style={{ margin: '0 0 14px 0' }}
                accentBarStyle={{
                  height: 4,
                  borderRadius: '2px',
                  background: 'linear-gradient(90deg, #8b5cf6, #3b82f6)',
                }}
                titleStyle={{
                  fontSize: '11px',
                  fontWeight: 700,
                  color: '#8b5cf6',
                  letterSpacing: '1px',
                  textTransform: 'uppercase',
                }}
              >
                Projects
              </SectionTitleAccent>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '12px' }}>
                {projects.map((project, idx) => {
                  const bgColors = ['#fce7f3', '#ede9fe', '#dbeafe'];
                  return (
                    <div key={project.id} style={{ width: 'calc(50% - 6px)', padding: '14px', backgroundColor: bgColors[idx % 3], borderRadius: '12px' }}>
                      <h3 style={{ fontSize: '11px', fontWeight: 700, color: '#1f2937', margin: 0 }}>{project.name}</h3>
                      {project.technologies && <p style={{ fontSize: '8px', color: '#8b5cf6', margin: '4px 0 0 0', fontWeight: 500 }}>{project.technologies}</p>}
                      {project.description && <p style={{ fontSize: '9px', color: '#6b7280', marginTop: '6px', lineHeight: '1.5', margin: '6px 0 0 0' }}>{project.description}</p>}
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

import { useResume } from '../../context/ResumeContext';
import { templateFonts } from '../fonts';

export function MinimalTemplate() {
  const { resumeData } = useResume();
  const { personalInfo, experiences, education, skills, projects, customFields } = resumeData;
  const validCustomFields = customFields.filter((cf) => cf.sectionTitle && cf.items.length > 0);
  const fonts = templateFonts;

  return (
    <div
      style={{
        width: '794px',
        height: '1123px',
        backgroundColor: '#ffffff',
        fontFamily: fonts.minimal,
        padding: '48px 56px',
        boxSizing: 'border-box',
      }}
    >
      <div style={{ textAlign: 'center', marginBottom: '32px', paddingBottom: '24px', borderBottom: '1px solid #e5e7eb' }}>
        {personalInfo.photo && (
          <img
            src={personalInfo.photo}
            alt=""
            style={{
              width: '90px',
              height: '90px',
              borderRadius: '50%',
              objectFit: 'cover',
              objectPosition: 'center',
              margin: '0 auto 16px auto',
              display: 'block',
            }}
          />
        )}
        <h1
          style={{
            fontSize: '32px',
            fontWeight: 400,
            color: '#111827',
            letterSpacing: '3px',
            margin: '0 0 8px 0',
            lineHeight: '1.2',
          }}
        >
          {(personalInfo.fullName || 'Your Name').toUpperCase()}
        </h1>
        <p style={{ fontSize: '13px', color: '#6b7280', letterSpacing: '2px', margin: 0 }}>
          {(personalInfo.title || 'Professional Title').toUpperCase()}
        </p>
        <div style={{ marginTop: '14px', fontSize: '10px', color: '#6b7280' }}>
          {[personalInfo.email, personalInfo.phone, personalInfo.location].filter(Boolean).join('  •  ')}
        </div>
      </div>
      {personalInfo.summary && (
        <div style={{ marginBottom: '28px', textAlign: 'center' }}>
          <p style={{ fontSize: '11px', lineHeight: '1.8', color: '#4b5563', fontStyle: 'italic', maxWidth: '560px', margin: '0 auto' }}>
            {personalInfo.summary}
          </p>
        </div>
      )}
      {experiences.length > 0 && (
        <div style={{ marginBottom: '28px' }}>
          <h2 style={{ fontSize: '11px', fontWeight: 400, letterSpacing: '3px', color: '#374151', marginBottom: '18px', textAlign: 'center', margin: '0 0 18px 0' }}>
            EXPERIENCE
          </h2>
          {experiences.map((exp, index) => (
            <div key={exp.id} style={{ marginBottom: index === experiences.length - 1 ? 0 : '18px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
                <h3 style={{ fontSize: '13px', fontWeight: 600, color: '#111827', margin: 0 }}>{exp.position}</h3>
                <span style={{ fontSize: '10px', color: '#9ca3af' }}>
                  {exp.startDate} — {exp.current ? 'Present' : exp.endDate}
                </span>
              </div>
              <p style={{ fontSize: '11px', color: '#6b7280', margin: '4px 0 0 0' }}>{exp.company}</p>
              {exp.description && <p style={{ fontSize: '10px', color: '#6b7280', lineHeight: '1.6', margin: '8px 0 0 0' }}>{exp.description}</p>}
            </div>
          ))}
        </div>
      )}
      <div style={{ display: 'flex', gap: '48px' }}>
        {education.length > 0 && (
          <div style={{ flex: 1 }}>
            <h2 style={{ fontSize: '11px', fontWeight: 400, letterSpacing: '3px', color: '#374151', margin: '0 0 16px 0' }}>EDUCATION</h2>
            {education.map((edu, index) => (
              <div key={edu.id} style={{ marginBottom: index === education.length - 1 ? 0 : '14px' }}>
                <h3 style={{ fontSize: '12px', fontWeight: 600, color: '#111827', margin: 0 }}>{edu.institution}</h3>
                <p style={{ fontSize: '10px', color: '#6b7280', margin: '3px 0 0 0' }}>
                  {edu.degree}
                  {edu.field && `, ${edu.field}`}
                </p>
                <p style={{ fontSize: '9px', color: '#9ca3af', margin: '2px 0 0 0' }}>
                  {edu.startDate} — {edu.endDate}
                </p>
              </div>
            ))}
          </div>
        )}
        {skills.length > 0 && (
          <div style={{ flex: 1 }}>
            <h2 style={{ fontSize: '11px', fontWeight: 400, letterSpacing: '3px', color: '#374151', margin: '0 0 16px 0' }}>SKILLS</h2>
            <p style={{ fontSize: '10px', color: '#4b5563', lineHeight: '2' }}>{skills.map((s) => s.name).filter(Boolean).join('  •  ')}</p>
          </div>
        )}
      </div>
      {projects.length > 0 && (
        <div style={{ marginTop: '28px' }}>
          <h2 style={{ fontSize: '11px', fontWeight: 400, letterSpacing: '3px', color: '#374151', margin: '0 0 16px 0' }}>PROJECTS</h2>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '16px' }}>
            {projects.map((project) => (
              <div key={project.id} style={{ width: 'calc(50% - 8px)' }}>
                <h3 style={{ fontSize: '11px', fontWeight: 600, color: '#111827', margin: 0 }}>{project.name}</h3>
                {project.technologies && <p style={{ fontSize: '9px', color: '#9ca3af', margin: '3px 0 0 0' }}>{project.technologies}</p>}
                {project.description && <p style={{ fontSize: '9px', color: '#6b7280', marginTop: '4px', lineHeight: '1.5', margin: '4px 0 0 0' }}>{project.description}</p>}
              </div>
            ))}
          </div>
        </div>
      )}
      {validCustomFields.length > 0 && (
        <div style={{ marginTop: '28px', display: 'flex', flexWrap: 'wrap', gap: '28px' }}>
          {validCustomFields.map((cf) => (
            <div key={cf.id} style={{ width: validCustomFields.length === 1 ? '100%' : 'calc(50% - 14px)' }}>
              <h2 style={{ fontSize: '11px', fontWeight: 400, letterSpacing: '3px', color: '#374151', margin: '0 0 14px 0' }}>{cf.sectionTitle.toUpperCase()}</h2>
              {cf.items.map((item, idx) => (
                <div key={item.id} style={{ marginBottom: idx === cf.items.length - 1 ? 0 : '10px' }}>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: '8px' }}>
                    <span style={{ fontSize: '11px', fontWeight: 600, color: '#111827' }}>{item.title}</span>
                    {item.subtitle && <span style={{ fontSize: '10px', color: '#9ca3af' }}>— {item.subtitle}</span>}
                  </div>
                  {item.description && <p style={{ fontSize: '9px', color: '#6b7280', margin: '2px 0 0 0' }}>{item.description}</p>}
                </div>
              ))}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

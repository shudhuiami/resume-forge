import { useResume } from '../../context/ResumeContext';
import { templateFonts } from '../fonts';

export function ExecutiveTemplate() {
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
        fontFamily: fonts.executive,
        padding: '44px 52px',
        boxSizing: 'border-box',
      }}
    >
      <div style={{ borderBottom: '3px solid #0f766e', paddingBottom: '20px', marginBottom: '24px', display: 'flex', alignItems: 'center', gap: '20px' }}>
        {personalInfo.photo && (
          <img
            src={personalInfo.photo}
            alt=""
            style={{ width: '85px', height: '85px', borderRadius: '6px', objectFit: 'cover', objectPosition: 'center', flexShrink: 0 }}
          />
        )}
        <div style={{ flex: 1 }}>
          <h1 style={{ fontSize: '28px', fontWeight: 700, color: '#0f766e', margin: '0 0 4px 0', lineHeight: '1.2' }}>{personalInfo.fullName || 'Your Name'}</h1>
          <p style={{ fontSize: '14px', color: '#374151', fontWeight: 500, margin: 0 }}>{personalInfo.title || 'Professional Title'}</p>
        </div>
        <div style={{ textAlign: 'right', fontSize: '10px', color: '#4b5563', lineHeight: '1.8' }}>
          {personalInfo.email && <div>{personalInfo.email}</div>}
          {personalInfo.phone && <div>{personalInfo.phone}</div>}
          {personalInfo.location && <div>{personalInfo.location}</div>}
          {personalInfo.linkedin && <div>{personalInfo.linkedin}</div>}
        </div>
      </div>
      {personalInfo.summary && (
        <div style={{ marginBottom: '22px' }}>
          <h2 style={{ fontSize: '12px', fontWeight: 700, color: '#0f766e', margin: '0 0 10px 0', borderBottom: '1px solid #d1d5db', paddingBottom: '4px' }}>PROFESSIONAL SUMMARY</h2>
          <p style={{ fontSize: '11px', lineHeight: '1.7', color: '#374151', margin: 0 }}>{personalInfo.summary}</p>
        </div>
      )}
      {experiences.length > 0 && (
        <div style={{ marginBottom: '22px' }}>
          <h2 style={{ fontSize: '12px', fontWeight: 700, color: '#0f766e', margin: '0 0 12px 0', borderBottom: '1px solid #d1d5db', paddingBottom: '4px' }}>PROFESSIONAL EXPERIENCE</h2>
          {experiences.map((exp, index) => (
            <div key={exp.id} style={{ marginBottom: index === experiences.length - 1 ? 0 : '14px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
                <h3 style={{ fontSize: '13px', fontWeight: 700, color: '#111827', margin: 0 }}>{exp.position}</h3>
                <span style={{ fontSize: '10px', color: '#6b7280' }}>
                  {exp.startDate} - {exp.current ? 'Present' : exp.endDate}
                </span>
              </div>
              <p style={{ fontSize: '11px', color: '#0f766e', fontWeight: 600, margin: '3px 0 0 0' }}>{exp.company}</p>
              {exp.description && <p style={{ fontSize: '10px', color: '#4b5563', lineHeight: '1.6', margin: '6px 0 0 0' }}>{exp.description}</p>}
            </div>
          ))}
        </div>
      )}
      <div style={{ display: 'flex', gap: '40px' }}>
        {education.length > 0 && (
          <div style={{ flex: 1 }}>
            <h2 style={{ fontSize: '12px', fontWeight: 700, color: '#0f766e', margin: '0 0 12px 0', borderBottom: '1px solid #d1d5db', paddingBottom: '4px' }}>EDUCATION</h2>
            {education.map((edu, index) => (
              <div key={edu.id} style={{ marginBottom: index === education.length - 1 ? 0 : '12px' }}>
                <h3 style={{ fontSize: '11px', fontWeight: 700, color: '#111827', margin: 0 }}>{edu.institution}</h3>
                <p style={{ fontSize: '10px', color: '#374151', margin: '2px 0 0 0' }}>
                  {edu.degree}
                  {edu.field && ` in ${edu.field}`}
                </p>
                <p style={{ fontSize: '9px', color: '#6b7280', margin: '2px 0 0 0' }}>
                  {edu.startDate} - {edu.endDate}
                </p>
              </div>
            ))}
          </div>
        )}
        {skills.length > 0 && (
          <div style={{ flex: 1 }}>
            <h2 style={{ fontSize: '12px', fontWeight: 700, color: '#0f766e', margin: '0 0 12px 0', borderBottom: '1px solid #d1d5db', paddingBottom: '4px' }}>CORE COMPETENCIES</h2>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px 16px' }}>
              {skills.map((skill) => (
                <div key={skill.id} style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <div style={{ width: '5px', height: '5px', borderRadius: '50%', backgroundColor: '#0f766e' }} />
                  <span style={{ fontSize: '10px', color: '#374151' }}>{skill.name}</span>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
      {projects.length > 0 && (
        <div style={{ marginTop: '22px' }}>
          <h2 style={{ fontSize: '12px', fontWeight: 700, color: '#0f766e', margin: '0 0 12px 0', borderBottom: '1px solid #d1d5db', paddingBottom: '4px' }}>KEY PROJECTS</h2>
          {projects.map((project, index) => (
            <div key={project.id} style={{ marginBottom: index === projects.length - 1 ? 0 : '12px' }}>
              <h3 style={{ fontSize: '11px', fontWeight: 700, color: '#111827', margin: 0 }}>{project.name}</h3>
              {project.technologies && <p style={{ fontSize: '9px', color: '#0f766e', margin: '2px 0 0 0' }}>Technologies: {project.technologies}</p>}
              {project.description && <p style={{ fontSize: '10px', color: '#4b5563', lineHeight: '1.5', margin: '4px 0 0 0' }}>{project.description}</p>}
            </div>
          ))}
        </div>
      )}
      {validCustomFields.length > 0 && (
        <div style={{ marginTop: '22px', display: 'flex', flexWrap: 'wrap', gap: '22px 40px' }}>
          {validCustomFields.map((cf) => (
            <div key={cf.id} style={{ width: validCustomFields.length === 1 ? '100%' : 'calc(50% - 20px)' }}>
              <h2 style={{ fontSize: '12px', fontWeight: 700, color: '#0f766e', margin: '0 0 12px 0', borderBottom: '1px solid #d1d5db', paddingBottom: '4px' }}>{cf.sectionTitle.toUpperCase()}</h2>
              {cf.items.map((item, idx) => (
                <div key={item.id} style={{ marginBottom: idx === cf.items.length - 1 ? 0 : '8px', display: 'flex', alignItems: 'baseline', gap: '8px' }}>
                  <div style={{ width: '5px', height: '5px', borderRadius: '50%', backgroundColor: '#0f766e', flexShrink: 0, marginTop: '4px' }} />
                  <div>
                    <span style={{ fontSize: '10px', fontWeight: 700, color: '#111827' }}>{item.title}</span>
                    {item.subtitle && <span style={{ fontSize: '10px', color: '#6b7280' }}> — {item.subtitle}</span>}
                    {item.description && <p style={{ fontSize: '9px', color: '#6b7280', margin: '2px 0 0 0' }}>{item.description}</p>}
                  </div>
                </div>
              ))}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

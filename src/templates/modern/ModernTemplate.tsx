import { useResume } from '../../context/ResumeContext';
import { templateFonts } from '../fonts';

export function ModernTemplate() {
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
        fontFamily: fonts.modern,
        display: 'flex',
        overflow: 'hidden',
      }}
    >
      <div
        style={{
          width: '260px',
          backgroundColor: '#1e293b',
          color: '#ffffff',
          padding: '32px 24px',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        {personalInfo.photo && (
          <div style={{ marginBottom: '24px', textAlign: 'center' }}>
            <img
              src={personalInfo.photo}
              alt=""
              style={{
                width: '120px',
                height: '120px',
                borderRadius: '50%',
                objectFit: 'cover',
                objectPosition: 'center',
                border: '4px solid #3b82f6',
                display: 'block',
                margin: '0 auto',
              }}
            />
          </div>
        )}
        <div style={{ marginBottom: '28px' }}>
          <h3
            style={{
              fontSize: '11px',
              fontWeight: 700,
              letterSpacing: '2px',
              marginBottom: '14px',
              color: '#3b82f6',
              margin: '0 0 14px 0',
            }}
          >
            CONTACT
          </h3>
          {personalInfo.email && (
            <div style={{ fontSize: '10px', marginBottom: '10px', color: '#cbd5e1', lineHeight: '1.4' }}>
              <div style={{ color: '#94a3b8', marginBottom: '2px', fontSize: '9px' }}>Email</div>
              <div style={{ wordBreak: 'break-all' }}>{personalInfo.email}</div>
            </div>
          )}
          {personalInfo.phone && (
            <div style={{ fontSize: '10px', marginBottom: '10px', color: '#cbd5e1', lineHeight: '1.4' }}>
              <div style={{ color: '#94a3b8', marginBottom: '2px', fontSize: '9px' }}>Phone</div>
              {personalInfo.phone}
            </div>
          )}
          {personalInfo.location && (
            <div style={{ fontSize: '10px', marginBottom: '10px', color: '#cbd5e1', lineHeight: '1.4' }}>
              <div style={{ color: '#94a3b8', marginBottom: '2px', fontSize: '9px' }}>Location</div>
              {personalInfo.location}
            </div>
          )}
          {personalInfo.linkedin && (
            <div style={{ fontSize: '10px', marginBottom: '10px', color: '#cbd5e1', lineHeight: '1.4' }}>
              <div style={{ color: '#94a3b8', marginBottom: '2px', fontSize: '9px' }}>LinkedIn</div>
              <div style={{ wordBreak: 'break-all' }}>{personalInfo.linkedin}</div>
            </div>
          )}
          {personalInfo.website && (
            <div style={{ fontSize: '10px', color: '#cbd5e1', lineHeight: '1.4' }}>
              <div style={{ color: '#94a3b8', marginBottom: '2px', fontSize: '9px' }}>Website</div>
              <div style={{ wordBreak: 'break-all' }}>{personalInfo.website}</div>
            </div>
          )}
        </div>
        {skills.length > 0 && (
          <div style={{ marginBottom: '28px' }}>
            <h3
              style={{
                fontSize: '11px',
                fontWeight: 700,
                letterSpacing: '2px',
                marginBottom: '14px',
                color: '#3b82f6',
                margin: '0 0 14px 0',
              }}
            >
              SKILLS
            </h3>
            {skills.map((skill, index) => (
              <div key={skill.id} style={{ marginBottom: index === skills.length - 1 ? 0 : '10px' }}>
                <div style={{ fontSize: '10px', color: '#e2e8f0', marginBottom: '4px' }}>{skill.name}</div>
                <div style={{ height: '4px', backgroundColor: '#334155', borderRadius: '2px', overflow: 'hidden' }}>
                  <div
                    style={{
                      height: '4px',
                      width: `${skill.level}%`,
                      backgroundColor: '#3b82f6',
                      borderRadius: '2px',
                    }}
                  />
                </div>
              </div>
            ))}
          </div>
        )}
        {education.length > 0 && (
          <div style={{ marginBottom: '28px' }}>
            <h3
              style={{
                fontSize: '11px',
                fontWeight: 700,
                letterSpacing: '2px',
                marginBottom: '14px',
                color: '#3b82f6',
                margin: '0 0 14px 0',
              }}
            >
              EDUCATION
            </h3>
            {education.map((edu, index) => (
              <div key={edu.id} style={{ marginBottom: index === education.length - 1 ? 0 : '14px' }}>
                <div style={{ fontSize: '11px', fontWeight: 600, color: '#f1f5f9', margin: 0, lineHeight: '1.3' }}>
                  {edu.degree}
                </div>
                {edu.field && <div style={{ fontSize: '10px', color: '#94a3b8', marginTop: '2px' }}>{edu.field}</div>}
                <div style={{ fontSize: '10px', color: '#cbd5e1', marginTop: '3px' }}>{edu.institution}</div>
                <div style={{ fontSize: '9px', color: '#64748b', marginTop: '2px' }}>
                  {edu.startDate} - {edu.endDate}
                </div>
              </div>
            ))}
          </div>
        )}
        {validCustomFields.map((cf) => (
          <div key={cf.id} style={{ marginBottom: '28px' }}>
            <h3
              style={{
                fontSize: '11px',
                fontWeight: 700,
                letterSpacing: '2px',
                marginBottom: '14px',
                color: '#3b82f6',
                margin: '0 0 14px 0',
              }}
            >
              {cf.sectionTitle.toUpperCase()}
            </h3>
            {cf.items.map((item, idx) => (
              <div key={item.id} style={{ marginBottom: idx === cf.items.length - 1 ? 0 : '10px' }}>
                <div style={{ fontSize: '10px', fontWeight: 600, color: '#e2e8f0' }}>{item.title}</div>
                {item.subtitle && <div style={{ fontSize: '9px', color: '#94a3b8', marginTop: '2px' }}>{item.subtitle}</div>}
                {item.description && <div style={{ fontSize: '9px', color: '#64748b', marginTop: '2px' }}>{item.description}</div>}
              </div>
            ))}
          </div>
        ))}
      </div>

      <div style={{ flex: 1, padding: '36px 32px' }}>
        <div style={{ marginBottom: '20px', borderBottom: '3px solid #3b82f6', paddingBottom: '16px' }}>
          <h1 style={{ fontSize: '28px', fontWeight: 700, color: '#1e293b', margin: '0 0 4px 0', lineHeight: '1.2' }}>
            {personalInfo.fullName || 'Your Name'}
          </h1>
          <p style={{ fontSize: '14px', color: '#3b82f6', fontWeight: 500, margin: 0 }}>{personalInfo.title || 'Professional Title'}</p>
        </div>
        {personalInfo.summary && (
          <div style={{ marginBottom: '20px' }}>
            <h2 style={{ fontSize: '12px', fontWeight: 700, letterSpacing: '1px', color: '#1e293b', margin: '0 0 8px 0' }}>PROFILE</h2>
            <p style={{ fontSize: '10px', lineHeight: '1.6', color: '#475569', margin: 0 }}>{personalInfo.summary}</p>
          </div>
        )}
        {experiences.length > 0 && (
          <div style={{ marginBottom: '20px' }}>
            <h2 style={{ fontSize: '12px', fontWeight: 700, letterSpacing: '1px', color: '#1e293b', margin: '0 0 12px 0' }}>EXPERIENCE</h2>
            {experiences.map((exp, index) => (
              <div
                key={exp.id}
                style={{
                  marginBottom: index === experiences.length - 1 ? 0 : '14px',
                  paddingLeft: '12px',
                  borderLeft: '2px solid #e2e8f0',
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                  <div>
                    <h3 style={{ fontSize: '12px', fontWeight: 600, color: '#1e293b', margin: 0 }}>{exp.position}</h3>
                    <p style={{ fontSize: '11px', color: '#3b82f6', margin: '2px 0 0 0' }}>{exp.company}</p>
                  </div>
                  <span style={{ fontSize: '9px', color: '#64748b', whiteSpace: 'nowrap' }}>
                    {exp.startDate} - {exp.current ? 'Present' : exp.endDate}
                  </span>
                </div>
                {exp.description && (
                  <p style={{ fontSize: '10px', color: '#64748b', marginTop: '6px', lineHeight: '1.5', margin: '6px 0 0 0' }}>{exp.description}</p>
                )}
              </div>
            ))}
          </div>
        )}
        {projects.length > 0 && (
          <div style={{ marginBottom: '20px' }}>
            <h2 style={{ fontSize: '12px', fontWeight: 700, letterSpacing: '1px', color: '#1e293b', margin: '0 0 12px 0' }}>PROJECTS</h2>
            {projects.map((project, index) => (
              <div
                key={project.id}
                style={{
                  marginBottom: index === projects.length - 1 ? 0 : '10px',
                  padding: '10px',
                  backgroundColor: '#f8fafc',
                  borderRadius: '6px',
                }}
              >
                <h3 style={{ fontSize: '11px', fontWeight: 600, color: '#1e293b', margin: 0 }}>{project.name}</h3>
                {project.technologies && <p style={{ fontSize: '9px', color: '#3b82f6', margin: '3px 0 0 0' }}>{project.technologies}</p>}
                {project.description && (
                  <p style={{ fontSize: '9px', color: '#64748b', marginTop: '4px', lineHeight: '1.4', margin: '4px 0 0 0' }}>{project.description}</p>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

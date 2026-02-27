import { forwardRef } from 'react';
import { useResume } from '../context/ResumeContext';
// Resume preview with all template renderers

export const ResumePreview = forwardRef<HTMLDivElement>((_, ref) => {
  const { resumeData, selectedTemplate } = useResume();
  const { personalInfo, experiences, education, skills, projects, customFields } = resumeData;

  const validCustomFields = customFields.filter(cf => cf.sectionTitle && cf.items.length > 0);

  const hasContent = personalInfo.fullName || personalInfo.email || experiences.length > 0 || education.length > 0 || skills.length > 0;

  const fonts = {
    modern: "'Inter', 'Segoe UI', sans-serif",
    minimal: "'Playfair Display', Georgia, serif",
    creative: "'Inter', 'Segoe UI', sans-serif",
    executive: "Georgia, 'Times New Roman', serif",
    tech: "'Source Code Pro', 'Courier New', monospace"
  };

  if (!hasContent) {
    return (
      <div
        ref={ref}
        style={{
          width: '794px',
          height: '1123px',
          backgroundColor: '#ffffff',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontFamily: fonts.modern
        }}
      >
        <div style={{ textAlign: 'center', color: '#9ca3af' }}>
          <div style={{
            width: '80px',
            height: '80px',
            margin: '0 auto 16px auto',
            borderRadius: '50%',
            backgroundColor: '#f3f4f6',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center'
          }}>
            <svg style={{ width: '40px', height: '40px', color: '#d1d5db' }} fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
          </div>
          <p style={{ fontSize: '18px', fontWeight: 500 }}>Start filling in your details</p>
          <p style={{ fontSize: '14px', marginTop: '4px' }}>Your resume preview will appear here</p>
        </div>
      </div>
    );
  }

  // ──────────── Template 1: Modern Professional ────────────
  // Custom fields are rendered inline in each template

  const renderModernTemplate = () => (
    <div style={{
      width: '794px',
      height: '1123px',
      backgroundColor: '#ffffff',
      fontFamily: fonts.modern,
      display: 'flex',
      overflow: 'hidden'
    }}>
      {/* Left Sidebar */}
      <div style={{
        width: '260px',
        backgroundColor: '#1e293b',
        color: '#ffffff',
        padding: '32px 24px',
        display: 'flex',
        flexDirection: 'column'
      }}>
        {personalInfo.photo && (
          <div style={{ marginBottom: '24px', textAlign: 'center' }}>
            <img src={personalInfo.photo} alt="" style={{ width: '120px', height: '120px', borderRadius: '50%', objectFit: 'cover', objectPosition: 'center', border: '4px solid #3b82f6', display: 'block', margin: '0 auto' }} />
          </div>
        )}
        <div style={{ marginBottom: '28px' }}>
          <h3 style={{ fontSize: '11px', fontWeight: 700, letterSpacing: '2px', marginBottom: '14px', color: '#3b82f6', margin: '0 0 14px 0' }}>CONTACT</h3>
          {personalInfo.email && (<div style={{ fontSize: '10px', marginBottom: '10px', color: '#cbd5e1', lineHeight: '1.4' }}><div style={{ color: '#94a3b8', marginBottom: '2px', fontSize: '9px' }}>Email</div><div style={{ wordBreak: 'break-all' }}>{personalInfo.email}</div></div>)}
          {personalInfo.phone && (<div style={{ fontSize: '10px', marginBottom: '10px', color: '#cbd5e1', lineHeight: '1.4' }}><div style={{ color: '#94a3b8', marginBottom: '2px', fontSize: '9px' }}>Phone</div>{personalInfo.phone}</div>)}
          {personalInfo.location && (<div style={{ fontSize: '10px', marginBottom: '10px', color: '#cbd5e1', lineHeight: '1.4' }}><div style={{ color: '#94a3b8', marginBottom: '2px', fontSize: '9px' }}>Location</div>{personalInfo.location}</div>)}
          {personalInfo.linkedin && (<div style={{ fontSize: '10px', marginBottom: '10px', color: '#cbd5e1', lineHeight: '1.4' }}><div style={{ color: '#94a3b8', marginBottom: '2px', fontSize: '9px' }}>LinkedIn</div><div style={{ wordBreak: 'break-all' }}>{personalInfo.linkedin}</div></div>)}
          {personalInfo.website && (<div style={{ fontSize: '10px', color: '#cbd5e1', lineHeight: '1.4' }}><div style={{ color: '#94a3b8', marginBottom: '2px', fontSize: '9px' }}>Website</div><div style={{ wordBreak: 'break-all' }}>{personalInfo.website}</div></div>)}
        </div>
        {skills.length > 0 && (
          <div style={{ marginBottom: '28px' }}>
            <h3 style={{ fontSize: '11px', fontWeight: 700, letterSpacing: '2px', marginBottom: '14px', color: '#3b82f6', margin: '0 0 14px 0' }}>SKILLS</h3>
            {skills.map((skill, index) => (
              <div key={skill.id} style={{ marginBottom: index === skills.length - 1 ? 0 : '10px' }}>
                <div style={{ fontSize: '10px', color: '#e2e8f0', marginBottom: '4px' }}>{skill.name}</div>
                <div style={{ height: '4px', backgroundColor: '#334155', borderRadius: '2px', overflow: 'hidden' }}>
                  <div style={{ height: '4px', width: `${skill.level}%`, backgroundColor: '#3b82f6', borderRadius: '2px' }} />
                </div>
              </div>
            ))}
          </div>
        )}
        {education.length > 0 && (
          <div style={{ marginBottom: '28px' }}>
            <h3 style={{ fontSize: '11px', fontWeight: 700, letterSpacing: '2px', marginBottom: '14px', color: '#3b82f6', margin: '0 0 14px 0' }}>EDUCATION</h3>
            {education.map((edu, index) => (
              <div key={edu.id} style={{ marginBottom: index === education.length - 1 ? 0 : '14px' }}>
                <div style={{ fontSize: '11px', fontWeight: 600, color: '#f1f5f9', margin: 0, lineHeight: '1.3' }}>{edu.degree}</div>
                {edu.field && <div style={{ fontSize: '10px', color: '#94a3b8', marginTop: '2px' }}>{edu.field}</div>}
                <div style={{ fontSize: '10px', color: '#cbd5e1', marginTop: '3px' }}>{edu.institution}</div>
                <div style={{ fontSize: '9px', color: '#64748b', marginTop: '2px' }}>{edu.startDate} - {edu.endDate}</div>
              </div>
            ))}
          </div>
        )}
        {/* Custom fields in sidebar */}
        {validCustomFields.map((cf) => (
          <div key={cf.id} style={{ marginBottom: '28px' }}>
            <h3 style={{ fontSize: '11px', fontWeight: 700, letterSpacing: '2px', marginBottom: '14px', color: '#3b82f6', margin: '0 0 14px 0' }}>{cf.sectionTitle.toUpperCase()}</h3>
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

      {/* Right Content */}
      <div style={{ flex: 1, padding: '36px 32px' }}>
        <div style={{ marginBottom: '20px', borderBottom: '3px solid #3b82f6', paddingBottom: '16px' }}>
          <h1 style={{ fontSize: '28px', fontWeight: 700, color: '#1e293b', margin: '0 0 4px 0', lineHeight: '1.2' }}>{personalInfo.fullName || 'Your Name'}</h1>
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
              <div key={exp.id} style={{ marginBottom: index === experiences.length - 1 ? 0 : '14px', paddingLeft: '12px', borderLeft: '2px solid #e2e8f0' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                  <div><h3 style={{ fontSize: '12px', fontWeight: 600, color: '#1e293b', margin: 0 }}>{exp.position}</h3><p style={{ fontSize: '11px', color: '#3b82f6', margin: '2px 0 0 0' }}>{exp.company}</p></div>
                  <span style={{ fontSize: '9px', color: '#64748b', whiteSpace: 'nowrap' }}>{exp.startDate} - {exp.current ? 'Present' : exp.endDate}</span>
                </div>
                {exp.description && (<p style={{ fontSize: '10px', color: '#64748b', marginTop: '6px', lineHeight: '1.5', margin: '6px 0 0 0' }}>{exp.description}</p>)}
              </div>
            ))}
          </div>
        )}
        {projects.length > 0 && (
          <div style={{ marginBottom: '20px' }}>
            <h2 style={{ fontSize: '12px', fontWeight: 700, letterSpacing: '1px', color: '#1e293b', margin: '0 0 12px 0' }}>PROJECTS</h2>
            {projects.map((project, index) => (
              <div key={project.id} style={{ marginBottom: index === projects.length - 1 ? 0 : '10px', padding: '10px', backgroundColor: '#f8fafc', borderRadius: '6px' }}>
                <h3 style={{ fontSize: '11px', fontWeight: 600, color: '#1e293b', margin: 0 }}>{project.name}</h3>
                {project.technologies && (<p style={{ fontSize: '9px', color: '#3b82f6', margin: '3px 0 0 0' }}>{project.technologies}</p>)}
                {project.description && (<p style={{ fontSize: '9px', color: '#64748b', marginTop: '4px', lineHeight: '1.4', margin: '4px 0 0 0' }}>{project.description}</p>)}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );

  // ──────────── Template 2: Minimalist Elegant ────────────
  const renderMinimalTemplate = () => (
    <div style={{
      width: '794px',
      height: '1123px',
      backgroundColor: '#ffffff',
      fontFamily: fonts.minimal,
      padding: '48px 56px',
      boxSizing: 'border-box'
    }}>
      <div style={{ textAlign: 'center', marginBottom: '32px', paddingBottom: '24px', borderBottom: '1px solid #e5e7eb' }}>
        {personalInfo.photo && (<img src={personalInfo.photo} alt="" style={{ width: '90px', height: '90px', borderRadius: '50%', objectFit: 'cover', objectPosition: 'center', margin: '0 auto 16px auto', display: 'block' }} />)}
        <h1 style={{ fontSize: '32px', fontWeight: 400, color: '#111827', letterSpacing: '3px', margin: '0 0 8px 0', lineHeight: '1.2' }}>{(personalInfo.fullName || 'Your Name').toUpperCase()}</h1>
        <p style={{ fontSize: '13px', color: '#6b7280', letterSpacing: '2px', margin: 0 }}>{(personalInfo.title || 'Professional Title').toUpperCase()}</p>
        <div style={{ marginTop: '14px', fontSize: '10px', color: '#6b7280' }}>{[personalInfo.email, personalInfo.phone, personalInfo.location].filter(Boolean).join('  •  ')}</div>
      </div>
      {personalInfo.summary && (
        <div style={{ marginBottom: '28px', textAlign: 'center' }}>
          <p style={{ fontSize: '11px', lineHeight: '1.8', color: '#4b5563', fontStyle: 'italic', maxWidth: '560px', margin: '0 auto' }}>{personalInfo.summary}</p>
        </div>
      )}
      {experiences.length > 0 && (
        <div style={{ marginBottom: '28px' }}>
          <h2 style={{ fontSize: '11px', fontWeight: 400, letterSpacing: '3px', color: '#374151', marginBottom: '18px', textAlign: 'center', margin: '0 0 18px 0' }}>EXPERIENCE</h2>
          {experiences.map((exp, index) => (
            <div key={exp.id} style={{ marginBottom: index === experiences.length - 1 ? 0 : '18px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
                <h3 style={{ fontSize: '13px', fontWeight: 600, color: '#111827', margin: 0 }}>{exp.position}</h3>
                <span style={{ fontSize: '10px', color: '#9ca3af' }}>{exp.startDate} — {exp.current ? 'Present' : exp.endDate}</span>
              </div>
              <p style={{ fontSize: '11px', color: '#6b7280', margin: '4px 0 0 0' }}>{exp.company}</p>
              {exp.description && (<p style={{ fontSize: '10px', color: '#6b7280', lineHeight: '1.6', margin: '8px 0 0 0' }}>{exp.description}</p>)}
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
                <p style={{ fontSize: '10px', color: '#6b7280', margin: '3px 0 0 0' }}>{edu.degree}{edu.field && `, ${edu.field}`}</p>
                <p style={{ fontSize: '9px', color: '#9ca3af', margin: '2px 0 0 0' }}>{edu.startDate} — {edu.endDate}</p>
              </div>
            ))}
          </div>
        )}
        {skills.length > 0 && (
          <div style={{ flex: 1 }}>
            <h2 style={{ fontSize: '11px', fontWeight: 400, letterSpacing: '3px', color: '#374151', margin: '0 0 16px 0' }}>SKILLS</h2>
            <p style={{ fontSize: '10px', color: '#4b5563', lineHeight: '2' }}>{skills.map(s => s.name).filter(Boolean).join('  •  ')}</p>
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
                {project.technologies && (<p style={{ fontSize: '9px', color: '#9ca3af', margin: '3px 0 0 0' }}>{project.technologies}</p>)}
                {project.description && (<p style={{ fontSize: '9px', color: '#6b7280', marginTop: '4px', lineHeight: '1.5', margin: '4px 0 0 0' }}>{project.description}</p>)}
              </div>
            ))}
          </div>
        </div>
      )}
      {/* Custom Fields for Minimal */}
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

  // ──────────── Template 3: Creative Light ────────────
  const renderCreativeTemplate = () => (
    <div style={{
      width: '794px',
      height: '1123px',
      backgroundColor: '#fefefe',
      fontFamily: fonts.creative,
      overflow: 'hidden',
      position: 'relative'
    }}>
      {/* Decorative Elements */}
      <div style={{ position: 'absolute', top: 0, right: 0, width: '200px', height: '200px', background: 'linear-gradient(135deg, #fce7f3 0%, #ddd6fe 100%)', borderRadius: '0 0 0 200px', opacity: 0.6 }} />
      <div style={{ position: 'absolute', bottom: 0, left: 0, width: '150px', height: '150px', background: 'linear-gradient(45deg, #e0f2fe 0%, #fce7f3 100%)', borderRadius: '0 150px 0 0', opacity: 0.5 }} />
      
      {/* Header */}
      <div style={{ padding: '40px 44px 32px 44px', position: 'relative', zIndex: 1 }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: '28px' }}>
          {personalInfo.photo && (
            <div style={{ position: 'relative' }}>
              <div style={{ position: 'absolute', top: '-6px', left: '-6px', width: '108px', height: '108px', borderRadius: '20px', background: 'linear-gradient(135deg, #f472b6 0%, #a78bfa 50%, #60a5fa 100%)', transform: 'rotate(3deg)' }} />
              <img src={personalInfo.photo} alt="" style={{ width: '96px', height: '96px', borderRadius: '16px', objectFit: 'cover', objectPosition: 'center', position: 'relative', zIndex: 1, border: '3px solid #ffffff' }} />
            </div>
          )}
          <div style={{ flex: 1 }}>
            <h1 style={{ fontSize: '32px', fontWeight: 800, margin: '0 0 6px 0', lineHeight: '1.1', background: 'linear-gradient(135deg, #ec4899 0%, #8b5cf6 50%, #3b82f6 100%)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent', backgroundClip: 'text' }}>{personalInfo.fullName || 'Your Name'}</h1>
            <p style={{ fontSize: '15px', color: '#6b7280', fontWeight: 500, margin: '0 0 12px 0', letterSpacing: '0.5px' }}>{personalInfo.title || 'Professional Title'}</p>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '12px', fontSize: '10px', color: '#6b7280' }}>
              {personalInfo.email && <span style={{ display: 'flex', alignItems: 'center', gap: '4px', padding: '4px 10px', backgroundColor: '#fdf2f8', borderRadius: '20px', color: '#be185d' }}>{personalInfo.email}</span>}
              {personalInfo.phone && <span style={{ display: 'flex', alignItems: 'center', gap: '4px', padding: '4px 10px', backgroundColor: '#f3e8ff', borderRadius: '20px', color: '#7c3aed' }}>{personalInfo.phone}</span>}
              {personalInfo.location && <span style={{ display: 'flex', alignItems: 'center', gap: '4px', padding: '4px 10px', backgroundColor: '#e0f2fe', borderRadius: '20px', color: '#0369a1' }}>{personalInfo.location}</span>}
            </div>
          </div>
        </div>
      </div>

      {/* Summary */}
      {personalInfo.summary && (
        <div style={{ padding: '0 44px', marginBottom: '24px', position: 'relative', zIndex: 1 }}>
          <div style={{ padding: '16px 20px', background: 'linear-gradient(135deg, #fdf2f8 0%, #faf5ff 50%, #eff6ff 100%)', borderRadius: '12px' }}>
            <p style={{ fontSize: '11px', lineHeight: '1.8', color: '#4b5563', margin: 0, fontStyle: 'italic' }}>"{personalInfo.summary}"</p>
          </div>
        </div>
      )}

      {/* Main Content */}
      <div style={{ padding: '0 44px', display: 'flex', gap: '32px', position: 'relative', zIndex: 1 }}>
        {/* Left Column */}
        <div style={{ width: '200px', flexShrink: 0 }}>
          {skills.length > 0 && (
            <div style={{ marginBottom: '24px' }}>
              <h2 style={{ fontSize: '11px', fontWeight: 700, color: '#ec4899', margin: '0 0 12px 0', letterSpacing: '1px', textTransform: 'uppercase', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <span style={{ width: '16px', height: '3px', background: 'linear-gradient(90deg, #ec4899, #8b5cf6)', borderRadius: '2px' }} />
                Skills
              </h2>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px' }}>
                {skills.map((skill, idx) => {
                  const colors = ['#fdf2f8', '#faf5ff', '#eff6ff', '#f0fdf4', '#fefce8'];
                  const textColors = ['#be185d', '#7c3aed', '#1d4ed8', '#15803d', '#a16207'];
                  return (
                    <span key={skill.id} style={{ padding: '5px 10px', backgroundColor: colors[idx % 5], borderRadius: '8px', fontSize: '9px', color: textColors[idx % 5], fontWeight: 600 }}>{skill.name}</span>
                  );
                })}
              </div>
            </div>
          )}
          
          {education.length > 0 && (
            <div style={{ marginBottom: '24px' }}>
              <h2 style={{ fontSize: '11px', fontWeight: 700, color: '#8b5cf6', margin: '0 0 12px 0', letterSpacing: '1px', textTransform: 'uppercase', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <span style={{ width: '16px', height: '3px', background: 'linear-gradient(90deg, #8b5cf6, #3b82f6)', borderRadius: '2px' }} />
                Education
              </h2>
              {education.map((edu, index) => (
                <div key={edu.id} style={{ marginBottom: index === education.length - 1 ? 0 : '14px', padding: '12px', backgroundColor: '#faf5ff', borderRadius: '10px' }}>
                  <div style={{ fontSize: '11px', fontWeight: 700, color: '#1f2937', margin: 0 }}>{edu.degree}</div>
                  {edu.field && <div style={{ fontSize: '9px', color: '#8b5cf6', marginTop: '2px', fontWeight: 500 }}>{edu.field}</div>}
                  <div style={{ fontSize: '10px', color: '#6b7280', marginTop: '4px' }}>{edu.institution}</div>
                  <div style={{ fontSize: '9px', color: '#9ca3af', marginTop: '3px' }}>{edu.startDate} - {edu.endDate}</div>
                </div>
              ))}
            </div>
          )}

          {/* Custom fields in sidebar */}
          {validCustomFields.map((cf) => (
            <div key={cf.id} style={{ marginBottom: '24px' }}>
              <h2 style={{ fontSize: '11px', fontWeight: 700, color: '#3b82f6', margin: '0 0 12px 0', letterSpacing: '1px', textTransform: 'uppercase', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <span style={{ width: '16px', height: '3px', background: 'linear-gradient(90deg, #3b82f6, #06b6d4)', borderRadius: '2px' }} />
                {cf.sectionTitle}
              </h2>
              {cf.items.map((item, idx) => (
                <div key={item.id} style={{ marginBottom: idx === cf.items.length - 1 ? 0 : '10px', padding: '10px', backgroundColor: '#eff6ff', borderRadius: '8px' }}>
                  <div style={{ fontSize: '10px', fontWeight: 600, color: '#1f2937' }}>{item.title}</div>
                  {item.subtitle && <div style={{ fontSize: '9px', color: '#3b82f6', marginTop: '2px' }}>{item.subtitle}</div>}
                  {item.description && <div style={{ fontSize: '9px', color: '#6b7280', marginTop: '2px' }}>{item.description}</div>}
                </div>
              ))}
            </div>
          ))}
        </div>

        {/* Right Column */}
        <div style={{ flex: 1 }}>
          {experiences.length > 0 && (
            <div style={{ marginBottom: '24px' }}>
              <h2 style={{ fontSize: '11px', fontWeight: 700, color: '#ec4899', margin: '0 0 14px 0', letterSpacing: '1px', textTransform: 'uppercase', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <span style={{ width: '16px', height: '3px', background: 'linear-gradient(90deg, #ec4899, #f472b6)', borderRadius: '2px' }} />
                Experience
              </h2>
              {experiences.map((exp, index) => (
                <div key={exp.id} style={{ marginBottom: index === experiences.length - 1 ? 0 : '16px', position: 'relative', paddingLeft: '16px' }}>
                  <div style={{ position: 'absolute', left: 0, top: '6px', width: '6px', height: '6px', borderRadius: '50%', background: 'linear-gradient(135deg, #ec4899, #8b5cf6)' }} />
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '4px' }}>
                    <div>
                      <h3 style={{ fontSize: '13px', fontWeight: 700, color: '#1f2937', margin: 0 }}>{exp.position}</h3>
                      <p style={{ fontSize: '11px', color: '#8b5cf6', margin: '2px 0 0 0', fontWeight: 500 }}>{exp.company}</p>
                    </div>
                    <span style={{ fontSize: '9px', color: '#ffffff', background: 'linear-gradient(135deg, #f472b6, #a78bfa)', padding: '3px 10px', borderRadius: '12px', whiteSpace: 'nowrap', fontWeight: 500 }}>{exp.startDate} - {exp.current ? 'Present' : exp.endDate}</span>
                  </div>
                  {exp.description && (<p style={{ fontSize: '10px', color: '#6b7280', marginTop: '8px', lineHeight: '1.6', margin: '8px 0 0 0' }}>{exp.description}</p>)}
                </div>
              ))}
            </div>
          )}

          {projects.length > 0 && (
            <div>
              <h2 style={{ fontSize: '11px', fontWeight: 700, color: '#8b5cf6', margin: '0 0 14px 0', letterSpacing: '1px', textTransform: 'uppercase', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <span style={{ width: '16px', height: '3px', background: 'linear-gradient(90deg, #8b5cf6, #3b82f6)', borderRadius: '2px' }} />
                Projects
              </h2>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '12px' }}>
                {projects.map((project, idx) => {
                  const bgColors = ['linear-gradient(135deg, #fdf2f8, #fce7f3)', 'linear-gradient(135deg, #faf5ff, #f3e8ff)', 'linear-gradient(135deg, #eff6ff, #dbeafe)'];
                  return (
                    <div key={project.id} style={{ width: 'calc(50% - 6px)', padding: '14px', background: bgColors[idx % 3], borderRadius: '12px' }}>
                      <h3 style={{ fontSize: '11px', fontWeight: 700, color: '#1f2937', margin: 0 }}>{project.name}</h3>
                      {project.technologies && (<p style={{ fontSize: '8px', color: '#8b5cf6', margin: '4px 0 0 0', fontWeight: 500 }}>{project.technologies}</p>)}
                      {project.description && (<p style={{ fontSize: '9px', color: '#6b7280', marginTop: '6px', lineHeight: '1.5', margin: '6px 0 0 0' }}>{project.description}</p>)}
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

  // ──────────── Template 4: Executive Classic ────────────
  const renderExecutiveTemplate = () => (
    <div style={{
      width: '794px',
      height: '1123px',
      backgroundColor: '#ffffff',
      fontFamily: fonts.executive,
      padding: '44px 52px',
      boxSizing: 'border-box'
    }}>
      <div style={{ borderBottom: '3px solid #0f766e', paddingBottom: '20px', marginBottom: '24px', display: 'flex', alignItems: 'center', gap: '20px' }}>
        {personalInfo.photo && (<img src={personalInfo.photo} alt="" style={{ width: '85px', height: '85px', borderRadius: '6px', objectFit: 'cover', objectPosition: 'center', flexShrink: 0 }} />)}
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
                <span style={{ fontSize: '10px', color: '#6b7280' }}>{exp.startDate} - {exp.current ? 'Present' : exp.endDate}</span>
              </div>
              <p style={{ fontSize: '11px', color: '#0f766e', fontWeight: 600, margin: '3px 0 0 0' }}>{exp.company}</p>
              {exp.description && (<p style={{ fontSize: '10px', color: '#4b5563', lineHeight: '1.6', margin: '6px 0 0 0' }}>{exp.description}</p>)}
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
                <p style={{ fontSize: '10px', color: '#374151', margin: '2px 0 0 0' }}>{edu.degree}{edu.field && ` in ${edu.field}`}</p>
                <p style={{ fontSize: '9px', color: '#6b7280', margin: '2px 0 0 0' }}>{edu.startDate} - {edu.endDate}</p>
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
              {project.technologies && (<p style={{ fontSize: '9px', color: '#0f766e', margin: '2px 0 0 0' }}>Technologies: {project.technologies}</p>)}
              {project.description && (<p style={{ fontSize: '10px', color: '#4b5563', lineHeight: '1.5', margin: '4px 0 0 0' }}>{project.description}</p>)}
            </div>
          ))}
        </div>
      )}
      {/* Custom Fields for Executive */}
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

  // ──────────── Template 5: Tech Developer ────────────
  const renderTechTemplate = () => (
    <div style={{
      width: '794px',
      height: '1123px',
      backgroundColor: '#0f172a',
      fontFamily: fonts.tech,
      color: '#e2e8f0',
      overflow: 'hidden'
    }}>
      <div style={{ padding: '36px 40px', borderBottom: '1px solid #334155', display: 'flex', alignItems: 'center', gap: '24px' }}>
        {personalInfo.photo && (<img src={personalInfo.photo} alt="" style={{ width: '90px', height: '90px', borderRadius: '10px', objectFit: 'cover', objectPosition: 'center', border: '3px solid #06b6d4', flexShrink: 0 }} />)}
        <div style={{ flex: 1 }}>
          <h1 style={{ fontSize: '26px', fontWeight: 700, color: '#ffffff', margin: '0 0 4px 0', lineHeight: '1.2' }}>{personalInfo.fullName || 'Your Name'}</h1>
          <p style={{ fontSize: '13px', color: '#06b6d4', margin: 0 }}>{personalInfo.title || 'Professional Title'}</p>
        </div>
        <div style={{ fontSize: '9px', color: '#94a3b8', lineHeight: '2', textAlign: 'right' }}>
          {personalInfo.email && <div><span style={{ color: '#06b6d4' }}>email:</span> {personalInfo.email}</div>}
          {personalInfo.phone && <div><span style={{ color: '#06b6d4' }}>phone:</span> {personalInfo.phone}</div>}
          {personalInfo.location && <div><span style={{ color: '#06b6d4' }}>location:</span> {personalInfo.location}</div>}
          {personalInfo.website && <div><span style={{ color: '#06b6d4' }}>web:</span> {personalInfo.website}</div>}
        </div>
      </div>
      <div style={{ padding: '28px 40px', display: 'flex', gap: '32px' }}>
        <div style={{ width: '200px', flexShrink: 0 }}>
          {skills.length > 0 && (
            <div style={{ marginBottom: '24px' }}>
              <h2 style={{ fontSize: '10px', fontWeight: 700, color: '#06b6d4', margin: '0 0 12px 0', letterSpacing: '1px' }}>{'<'} TECH_STACK {'>'}</h2>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px' }}>
                {skills.map((skill) => (<span key={skill.id} style={{ fontSize: '9px', padding: '4px 8px', backgroundColor: '#1e293b', border: '1px solid #334155', borderRadius: '4px', color: '#94a3b8' }}>{skill.name}</span>))}
              </div>
            </div>
          )}
          {education.length > 0 && (
            <div style={{ marginBottom: '24px' }}>
              <h2 style={{ fontSize: '10px', fontWeight: 700, color: '#06b6d4', margin: '0 0 12px 0', letterSpacing: '1px' }}>{'<'} EDUCATION {'>'}</h2>
              {education.map((edu, index) => (
                <div key={edu.id} style={{ marginBottom: index === education.length - 1 ? 0 : '12px', padding: '10px', backgroundColor: '#1e293b', borderRadius: '6px', borderLeft: '3px solid #06b6d4' }}>
                  <div style={{ fontSize: '10px', fontWeight: 600, color: '#f1f5f9', margin: 0 }}>{edu.degree}</div>
                  <div style={{ fontSize: '9px', color: '#94a3b8', marginTop: '3px' }}>{edu.institution}</div>
                  <div style={{ fontSize: '8px', color: '#64748b', marginTop: '4px' }}>{edu.startDate} - {edu.endDate}</div>
                </div>
              ))}
            </div>
          )}
          {/* Custom fields in sidebar for tech */}
          {validCustomFields.map((cf) => (
            <div key={cf.id} style={{ marginBottom: '24px' }}>
              <h2 style={{ fontSize: '10px', fontWeight: 700, color: '#06b6d4', margin: '0 0 12px 0', letterSpacing: '1px' }}>{'<'} {cf.sectionTitle.toUpperCase().replace(/ /g, '_')} {'>'}</h2>
              {cf.items.map((item, idx) => (
                <div key={item.id} style={{ marginBottom: idx === cf.items.length - 1 ? 0 : '8px', padding: '8px 10px', backgroundColor: '#1e293b', borderRadius: '4px', borderLeft: '2px solid #334155' }}>
                  <div style={{ fontSize: '9px', fontWeight: 600, color: '#e2e8f0' }}>{item.title}</div>
                  {item.subtitle && <div style={{ fontSize: '8px', color: '#06b6d4', marginTop: '2px' }}>{item.subtitle}</div>}
                  {item.description && <div style={{ fontSize: '8px', color: '#64748b', marginTop: '2px' }}>{item.description}</div>}
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
                    <div><h3 style={{ fontSize: '12px', fontWeight: 600, color: '#f1f5f9', margin: 0 }}>{exp.position}</h3><p style={{ fontSize: '10px', color: '#06b6d4', margin: '3px 0 0 0' }}>{exp.company}</p></div>
                    <span style={{ fontSize: '8px', color: '#64748b', backgroundColor: '#0f172a', padding: '3px 8px', borderRadius: '4px' }}>{exp.startDate} → {exp.current ? 'present' : exp.endDate}</span>
                  </div>
                  {exp.description && (<p style={{ fontSize: '9px', color: '#94a3b8', marginTop: '10px', lineHeight: '1.6', margin: '10px 0 0 0' }}>{exp.description}</p>)}
                </div>
              ))}
            </div>
          )}
          {projects.length > 0 && (
            <div>
              <h2 style={{ fontSize: '10px', fontWeight: 700, color: '#06b6d4', margin: '0 0 12px 0', letterSpacing: '1px' }}>{'<'} PROJECTS {'>'}</h2>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '10px' }}>
                {projects.map((project) => (
                  <div key={project.id} style={{ width: 'calc(50% - 5px)', padding: '12px', backgroundColor: '#1e293b', borderRadius: '8px', border: '1px solid #334155' }}>
                    <h3 style={{ fontSize: '10px', fontWeight: 600, color: '#f1f5f9', margin: 0 }}>{project.name}</h3>
                    {project.technologies && (<p style={{ fontSize: '8px', color: '#06b6d4', margin: '4px 0 0 0' }}>[{project.technologies}]</p>)}
                    {project.description && (<p style={{ fontSize: '8px', color: '#94a3b8', marginTop: '6px', lineHeight: '1.5', margin: '6px 0 0 0' }}>{project.description}</p>)}
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );

  const renderTemplate = () => {
    switch (selectedTemplate?.id) {
      case 'modern': return renderModernTemplate();
      case 'minimal': return renderMinimalTemplate();
      case 'creative': return renderCreativeTemplate();
      case 'executive': return renderExecutiveTemplate();
      case 'tech': return renderTechTemplate();
      default: return renderModernTemplate();
    }
  };

  return (
    <div ref={ref} data-resume-preview style={{ width: '794px', height: '1123px', overflow: 'hidden' }}>
      {renderTemplate()}
    </div>
  );
});

ResumePreview.displayName = 'ResumePreview';

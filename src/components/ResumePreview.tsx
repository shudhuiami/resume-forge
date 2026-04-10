import { forwardRef } from 'react';
import { useResume } from '../context/ResumeContext';
import { A4_HEIGHT_PX, A4_WIDTH_PX } from '../constants/layout';
import { getTemplateComponent } from '../templates/registry';
import { templateFonts } from '../templates/fonts';

export const ResumePreview = forwardRef<HTMLDivElement>((_, ref) => {
  const { resumeData, selectedTemplate } = useResume();
  const { personalInfo, experiences, education, skills } = resumeData;

  const hasContent =
    personalInfo.fullName ||
    personalInfo.email ||
    experiences.length > 0 ||
    education.length > 0 ||
    skills.length > 0;

  const Template = getTemplateComponent(selectedTemplate?.id);

  if (!hasContent) {
    return (
      <div
        ref={ref}
        style={{
          width: A4_WIDTH_PX,
          height: A4_HEIGHT_PX,
          backgroundColor: '#ffffff',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontFamily: templateFonts.modern,
        }}
      >
        <div style={{ textAlign: 'center', color: '#9ca3af' }}>
          <div
            style={{
              width: '80px',
              height: '80px',
              margin: '0 auto 16px auto',
              borderRadius: '50%',
              backgroundColor: '#f3f4f6',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
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

  return (
    <div ref={ref} data-resume-preview style={{ width: A4_WIDTH_PX, height: A4_HEIGHT_PX, overflow: 'hidden' }}>
      <Template />
    </div>
  );
});

ResumePreview.displayName = 'ResumePreview';

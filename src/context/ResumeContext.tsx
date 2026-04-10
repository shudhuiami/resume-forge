import React, { createContext, useContext, useState, ReactNode } from 'react';
import { ResumeData, Template } from '../types/resume';

const defaultResumeData: ResumeData = {
  personalInfo: {
    fullName: '',
    email: '',
    phone: '',
    location: '',
    title: '',
    summary: '',
    linkedin: '',
    website: '',
    photo: '',
  },
  experiences: [],
  education: [],
  skills: [],
  projects: [],
  customFields: [],
};

interface ResumeContextType {
  resumeData: ResumeData;
  setResumeData: React.Dispatch<React.SetStateAction<ResumeData>>;
  selectedTemplate: Template | null;
  setSelectedTemplate: React.Dispatch<React.SetStateAction<Template | null>>;
}

const ResumeContext = createContext<ResumeContextType | undefined>(undefined);

export function ResumeProvider({
  children,
  initialResumeData,
  initialTemplate = null,
}: {
  children: ReactNode;
  /** Used by template gallery / tests; app shell omits this. */
  initialResumeData?: ResumeData;
  initialTemplate?: Template | null;
}) {
  const [resumeData, setResumeData] = useState<ResumeData>(
    () => initialResumeData ?? defaultResumeData
  );
  const [selectedTemplate, setSelectedTemplate] = useState<Template | null>(
    () => initialTemplate ?? null
  );

  return (
    <ResumeContext.Provider value={{ resumeData, setResumeData, selectedTemplate, setSelectedTemplate }}>
      {children}
    </ResumeContext.Provider>
  );
}

export function useResume() {
  const context = useContext(ResumeContext);
  if (!context) {
    throw new Error('useResume must be used within a ResumeProvider');
  }
  return context;
}

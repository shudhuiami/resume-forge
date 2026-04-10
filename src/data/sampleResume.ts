import type { ResumeData } from '../types/resume';

/** Deterministic fixture for gallery thumbnails and Playwright visual tests. */
export const sampleResume: ResumeData = {
  personalInfo: {
    fullName: 'Jordan Lee',
    email: 'jordan.lee@example.com',
    phone: '(555) 010-2030',
    location: 'Austin, TX',
    title: 'Senior Product Engineer',
    summary:
      'Product-minded engineer focused on scalable frontends, clear UX, and measurable outcomes. Led cross-functional teams shipping releases used by millions.',
    linkedin: 'linkedin.com/in/jordanlee',
    website: 'jordanlee.dev',
    photo: '',
  },
  experiences: [
    {
      id: 'e1',
      company: 'Northwind Labs',
      position: 'Senior Software Engineer',
      startDate: '2021-03',
      endDate: '',
      current: true,
      description:
        'Owned the design system and performance program; cut LCP by 38% and improved accessibility scores across core flows.',
    },
    {
      id: 'e2',
      company: 'Contoso Apps',
      position: 'Software Engineer',
      startDate: '2018-06',
      endDate: '2021-02',
      current: false,
      description:
        'Built customer-facing dashboards with React and TypeScript; partnered with design on a unified component library.',
    },
  ],
  education: [
    {
      id: 'ed1',
      institution: 'State University',
      degree: 'B.S. Computer Science',
      field: 'Human–Computer Interaction',
      startDate: '2014',
      endDate: '2018',
      gpa: '3.7',
    },
  ],
  skills: [
    { id: 's1', name: 'TypeScript', level: 95 },
    { id: 's2', name: 'React', level: 92 },
    { id: 's3', name: 'Node.js', level: 85 },
    { id: 's4', name: 'System design', level: 80 },
  ],
  projects: [
    {
      id: 'p1',
      name: 'ResumeForge',
      description: 'Static resume builder with PDF export and template gallery.',
      link: 'https://example.com',
      technologies: 'Vite · React · Tailwind',
    },
  ],
  customFields: [
    {
      id: 'cf1',
      sectionTitle: 'Volunteering',
      items: [
        {
          id: 'cfi1',
          title: 'Open Source Mentor',
          subtitle: '2020 — Present',
          description: 'Weekly office hours for first-time contributors.',
        },
      ],
    },
  ],
};

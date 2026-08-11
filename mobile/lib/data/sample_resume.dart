import '../models/resume.dart';

/// Realistic filler used for template thumbnails, the gallery, and tests.
///
/// Deliberately contains awkward content — a long summary, a long company name,
/// five skills, a two-line project description — so template layouts are
/// exercised against realistic text rather than short happy-path strings.
final sampleResume = ResumeData(
  personalInfo: const PersonalInfo(
    fullName: 'Amara Okonkwo',
    title: 'Senior Product Designer',
    email: 'amara.okonkwo@example.com',
    phone: '+1 (415) 555-0134',
    location: 'San Francisco, CA',
    summary:
        'Product designer with nine years shaping data-heavy consumer and B2B '
        'products. Leads design systems work end to end, partners closely with '
        'engineering on delivery, and measures success in adoption rather than '
        'artefacts.',
    linkedin: 'linkedin.com/in/amaraokonkwo',
    website: 'amara.design',
  ),
  experiences: const [
    Experience(
      id: 'exp-1',
      company: 'Northwind Analytics International',
      position: 'Senior Product Designer',
      startDate: '2021-03',
      endDate: '',
      current: true,
      description:
          'Own the design system used across six product surfaces. Cut new '
          'feature design time by roughly 40% by replacing bespoke screens with '
          'a shared component library.',
    ),
    Experience(
      id: 'exp-2',
      company: 'Kestrel Labs',
      position: 'Product Designer',
      startDate: '2018-06',
      endDate: '2021-02',
      description:
          'Redesigned the onboarding flow, lifting activation from 34% to 58%. '
          'Ran the first accessibility audit and closed every AA contrast issue.',
    ),
    Experience(
      id: 'exp-3',
      company: 'Bright Fold Studio',
      position: 'UI Designer',
      startDate: '2016-09',
      endDate: '2018-05',
      description:
          'Delivered interface work for a dozen client engagements across '
          'fintech, health, and logistics.',
    ),
  ],
  education: const [
    Education(
      id: 'edu-1',
      institution: 'Rhode Island School of Design',
      degree: 'BFA',
      field: 'Graphic Design',
      startDate: '2012-09',
      endDate: '2016-05',
      gpa: '3.8',
    ),
  ],
  skills: const [
    Skill(id: 'sk-1', name: 'Design systems', level: 5),
    Skill(id: 'sk-2', name: 'Prototyping', level: 5),
    Skill(id: 'sk-3', name: 'User research', level: 4),
    Skill(id: 'sk-4', name: 'Accessibility', level: 4),
    Skill(id: 'sk-5', name: 'Front-end (HTML/CSS)', level: 3),
  ],
  projects: const [
    Project(
      id: 'prj-1',
      name: 'Atlas Design System',
      description:
          'Open-source component library adopted by four internal teams and '
          'about 200 external developers.',
      link: 'github.com/example/atlas',
      technologies: 'Figma, React, Storybook',
    ),
    Project(
      id: 'prj-2',
      name: 'Fieldnote',
      description:
          'Offline-first research note-taking app for interview transcription '
          'and tagging.',
      link: 'fieldnote.example',
      technologies: 'Flutter, SQLite',
    ),
  ],
  customSections: const [
    CustomSection(
      id: 'cs-1',
      sectionTitle: 'Certifications',
      items: [
        CustomItem(
          id: 'ci-1',
          title: 'Certified Professional in Accessibility Core Competencies',
          subtitle: 'IAAP · 2023',
        ),
      ],
    ),
  ],
);

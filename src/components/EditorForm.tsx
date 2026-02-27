import { useState, useRef } from 'react';
import { useResume } from '../context/ResumeContext';
import { Experience, Education, Skill, Project, ResumeData, CustomField, CustomFieldItem } from '../types/resume';
import { Plus, Trash2, ChevronDown, ChevronUp, User, Briefcase, GraduationCap, Wrench, FolderOpen, Sparkles, RotateCcw, Camera, X, Layers, Pencil } from 'lucide-react';

const sampleData: ResumeData = {
  personalInfo: {
    fullName: 'Alex Johnson',
    title: 'Senior Full Stack Developer',
    email: 'alex.johnson@email.com',
    phone: '+1 (555) 123-4567',
    location: 'San Francisco, CA',
    linkedin: 'linkedin.com/in/alexjohnson',
    website: 'alexjohnson.dev',
    photo: '',
    summary: 'Passionate full-stack developer with 8+ years of experience building scalable web applications. Expert in React, Node.js, and cloud technologies. Led teams of up to 10 developers and delivered projects that increased user engagement by 40%. Strong advocate for clean code, test-driven development, and continuous learning.',
  },
  experiences: [
    {
      id: '1',
      company: 'TechCorp Inc.',
      position: 'Senior Full Stack Developer',
      startDate: 'Jan 2021',
      endDate: '',
      current: true,
      description: 'Leading development of microservices architecture serving 2M+ users. Reduced API response times by 60% through optimization. Mentoring junior developers and conducting code reviews.',
    },
    {
      id: '2',
      company: 'StartupXYZ',
      position: 'Full Stack Developer',
      startDate: 'Mar 2018',
      endDate: 'Dec 2020',
      current: false,
      description: 'Built and maintained e-commerce platform from scratch. Implemented payment integrations and real-time inventory management. Increased conversion rate by 25% through UX improvements.',
    },
  ],
  education: [
    {
      id: '1',
      institution: 'Stanford University',
      degree: 'Master of Science',
      field: 'Computer Science',
      startDate: 'Sep 2014',
      endDate: 'Jun 2016',
      gpa: '3.9',
    },
    {
      id: '2',
      institution: 'UC Berkeley',
      degree: 'Bachelor of Science',
      field: 'Computer Science',
      startDate: 'Sep 2010',
      endDate: 'May 2014',
      gpa: '3.7',
    },
  ],
  skills: [
    { id: '1', name: 'React / Next.js', level: 95 },
    { id: '2', name: 'TypeScript', level: 90 },
    { id: '3', name: 'Node.js', level: 88 },
    { id: '4', name: 'PostgreSQL', level: 85 },
    { id: '5', name: 'AWS / Cloud', level: 82 },
    { id: '6', name: 'Docker / K8s', level: 78 },
  ],
  projects: [
    {
      id: '1',
      name: 'E-Commerce Platform',
      description: 'Full-featured e-commerce platform with real-time inventory, payment processing, and admin dashboard.',
      link: 'github.com/alex/ecommerce',
      technologies: 'Next.js, Stripe, PostgreSQL, Redis',
    },
    {
      id: '2',
      name: 'Task Management App',
      description: 'Collaborative project management tool with real-time updates and team features.',
      link: 'github.com/alex/taskapp',
      technologies: 'React, Socket.io, Node.js, MongoDB',
    },
  ],
  customFields: [
    {
      id: 'cf1',
      sectionTitle: 'Languages',
      items: [
        { id: 'l1', title: 'English', subtitle: 'Native', description: '' },
        { id: 'l2', title: 'Spanish', subtitle: 'Professional Working', description: '' },
        { id: 'l3', title: 'French', subtitle: 'Conversational', description: '' },
      ],
    },
    {
      id: 'cf2',
      sectionTitle: 'Certifications',
      items: [
        { id: 'c1', title: 'AWS Solutions Architect', subtitle: 'Amazon Web Services', description: 'Issued Dec 2022' },
        { id: 'c2', title: 'Google Cloud Professional', subtitle: 'Google', description: 'Issued Aug 2021' },
      ],
    },
  ],
};

type Section = 'personal' | 'experience' | 'education' | 'skills' | 'projects' | 'custom';

export function EditorForm() {
  const { resumeData, setResumeData } = useResume();
  const [expandedSections, setExpandedSections] = useState<Section[]>(['personal']);

  const loadSampleData = () => {
    setResumeData(sampleData);
    setExpandedSections(['personal', 'experience', 'education', 'skills', 'projects', 'custom']);
  };

  const clearAllData = () => {
    setResumeData({
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
    });
  };

  const handlePhotoUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onloadend = () => {
        updatePersonalInfo('photo', reader.result as string);
      };
      reader.readAsDataURL(file);
    }
  };

  const removePhoto = () => {
    updatePersonalInfo('photo', '');
  };

  const fileInputRef = useRef<HTMLInputElement>(null);

  const toggleSection = (section: Section) => {
    setExpandedSections((prev) =>
      prev.includes(section)
        ? prev.filter((s) => s !== section)
        : [...prev, section]
    );
  };

  const updatePersonalInfo = (field: string, value: string) => {
    setResumeData((prev) => ({
      ...prev,
      personalInfo: { ...prev.personalInfo, [field]: value },
    }));
  };

  const addExperience = () => {
    const newExp: Experience = {
      id: Date.now().toString(),
      company: '',
      position: '',
      startDate: '',
      endDate: '',
      current: false,
      description: '',
    };
    setResumeData((prev) => ({
      ...prev,
      experiences: [...prev.experiences, newExp],
    }));
  };

  const updateExperience = (id: string, field: string, value: string | boolean) => {
    setResumeData((prev) => ({
      ...prev,
      experiences: prev.experiences.map((exp) =>
        exp.id === id ? { ...exp, [field]: value } : exp
      ),
    }));
  };

  const removeExperience = (id: string) => {
    setResumeData((prev) => ({
      ...prev,
      experiences: prev.experiences.filter((exp) => exp.id !== id),
    }));
  };

  const addEducation = () => {
    const newEdu: Education = {
      id: Date.now().toString(),
      institution: '',
      degree: '',
      field: '',
      startDate: '',
      endDate: '',
      gpa: '',
    };
    setResumeData((prev) => ({
      ...prev,
      education: [...prev.education, newEdu],
    }));
  };

  const updateEducation = (id: string, field: string, value: string) => {
    setResumeData((prev) => ({
      ...prev,
      education: prev.education.map((edu) =>
        edu.id === id ? { ...edu, [field]: value } : edu
      ),
    }));
  };

  const removeEducation = (id: string) => {
    setResumeData((prev) => ({
      ...prev,
      education: prev.education.filter((edu) => edu.id !== id),
    }));
  };

  const addSkill = () => {
    const newSkill: Skill = {
      id: Date.now().toString(),
      name: '',
      level: 80,
    };
    setResumeData((prev) => ({
      ...prev,
      skills: [...prev.skills, newSkill],
    }));
  };

  const updateSkill = (id: string, field: string, value: string | number) => {
    setResumeData((prev) => ({
      ...prev,
      skills: prev.skills.map((skill) =>
        skill.id === id ? { ...skill, [field]: value } : skill
      ),
    }));
  };

  const removeSkill = (id: string) => {
    setResumeData((prev) => ({
      ...prev,
      skills: prev.skills.filter((skill) => skill.id !== id),
    }));
  };

  const addProject = () => {
    const newProject: Project = {
      id: Date.now().toString(),
      name: '',
      description: '',
      link: '',
      technologies: '',
    };
    setResumeData((prev) => ({
      ...prev,
      projects: [...prev.projects, newProject],
    }));
  };

  const updateProject = (id: string, field: string, value: string) => {
    setResumeData((prev) => ({
      ...prev,
      projects: prev.projects.map((proj) =>
        proj.id === id ? { ...proj, [field]: value } : proj
      ),
    }));
  };

  const removeProject = (id: string) => {
    setResumeData((prev) => ({
      ...prev,
      projects: prev.projects.filter((proj) => proj.id !== id),
    }));
  };

  // Custom Fields CRUD
  const addCustomSection = () => {
    const newSection: CustomField = {
      id: Date.now().toString(),
      sectionTitle: '',
      items: [],
    };
    setResumeData((prev) => ({
      ...prev,
      customFields: [...prev.customFields, newSection],
    }));
    if (!expandedSections.includes('custom')) {
      setExpandedSections((prev) => [...prev, 'custom']);
    }
  };

  const updateCustomSectionTitle = (sectionId: string, title: string) => {
    setResumeData((prev) => ({
      ...prev,
      customFields: prev.customFields.map((cf) =>
        cf.id === sectionId ? { ...cf, sectionTitle: title } : cf
      ),
    }));
  };

  const removeCustomSection = (sectionId: string) => {
    setResumeData((prev) => ({
      ...prev,
      customFields: prev.customFields.filter((cf) => cf.id !== sectionId),
    }));
  };

  const addCustomItem = (sectionId: string) => {
    const newItem: CustomFieldItem = {
      id: Date.now().toString(),
      title: '',
      subtitle: '',
      description: '',
    };
    setResumeData((prev) => ({
      ...prev,
      customFields: prev.customFields.map((cf) =>
        cf.id === sectionId ? { ...cf, items: [...cf.items, newItem] } : cf
      ),
    }));
  };

  const updateCustomItem = (sectionId: string, itemId: string, field: string, value: string) => {
    setResumeData((prev) => ({
      ...prev,
      customFields: prev.customFields.map((cf) =>
        cf.id === sectionId
          ? {
              ...cf,
              items: cf.items.map((item) =>
                item.id === itemId ? { ...item, [field]: value } : item
              ),
            }
          : cf
      ),
    }));
  };

  const removeCustomItem = (sectionId: string, itemId: string) => {
    setResumeData((prev) => ({
      ...prev,
      customFields: prev.customFields.map((cf) =>
        cf.id === sectionId
          ? { ...cf, items: cf.items.filter((item) => item.id !== itemId) }
          : cf
      ),
    }));
  };

  const SectionHeader = ({
    section,
    icon,
    title,
    count,
  }: {
    section: Section;
    icon: React.ReactNode;
    title: string;
    count?: number;
  }) => (
    <button
      onClick={() => toggleSection(section)}
      className="w-full flex items-center justify-between p-4 bg-slate-800/50 rounded-xl hover:bg-slate-800 transition-colors"
    >
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center">
          {icon}
        </div>
        <div className="text-left">
          <h3 className="font-semibold text-white">{title}</h3>
          {count !== undefined && (
            <p className="text-sm text-slate-400">{count} items</p>
          )}
        </div>
      </div>
      {expandedSections.includes(section) ? (
        <ChevronUp className="w-5 h-5 text-slate-400" />
      ) : (
        <ChevronDown className="w-5 h-5 text-slate-400" />
      )}
    </button>
  );

  const inputClass =
    'w-full px-4 py-3 bg-slate-800/50 border border-slate-700 rounded-xl text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition-colors';

  const labelClass = 'block text-sm font-medium text-slate-300 mb-2';

  return (
    <div className="space-y-4">
      {/* Quick Actions */}
      <div className="flex gap-3 mb-6">
        <button
          onClick={loadSampleData}
          className="flex-1 flex items-center justify-center gap-2 px-4 py-3 bg-gradient-to-r from-emerald-500/20 to-teal-500/20 border border-emerald-500/30 rounded-xl text-emerald-300 hover:bg-emerald-500/30 transition-colors"
        >
          <Sparkles className="w-4 h-4" />
          Load Sample Data
        </button>
        <button
          onClick={clearAllData}
          className="flex items-center justify-center gap-2 px-4 py-3 bg-slate-800/50 border border-slate-700 rounded-xl text-slate-400 hover:text-red-400 hover:border-red-500/30 transition-colors"
        >
          <RotateCcw className="w-4 h-4" />
          Clear
        </button>
      </div>

      {/* Personal Information */}
      <div className="bg-slate-900/50 rounded-2xl overflow-hidden border border-white/5">
        <SectionHeader
          section="personal"
          icon={<User className="w-5 h-5 text-white" />}
          title="Personal Information"
        />
        {expandedSections.includes('personal') && (
          <div className="p-4 space-y-4">
            {/* Photo Upload */}
            <div className="flex items-center gap-4">
              <div className="relative">
                {resumeData.personalInfo.photo ? (
                  <div className="relative group">
                    <img
                      src={resumeData.personalInfo.photo}
                      alt="Profile"
                      className="w-24 h-24 rounded-2xl object-cover border-2 border-emerald-500"
                    />
                    <button
                      onClick={removePhoto}
                      className="absolute -top-2 -right-2 w-6 h-6 bg-red-500 rounded-full flex items-center justify-center text-white opacity-0 group-hover:opacity-100 transition-opacity"
                    >
                      <X className="w-4 h-4" />
                    </button>
                  </div>
                ) : (
                  <div
                    onClick={() => fileInputRef.current?.click()}
                    className="w-24 h-24 rounded-2xl bg-slate-800 border-2 border-dashed border-slate-600 flex flex-col items-center justify-center cursor-pointer hover:border-emerald-500 transition-colors"
                  >
                    <Camera className="w-8 h-8 text-slate-500" />
                    <span className="text-xs text-slate-500 mt-1">Add Photo</span>
                  </div>
                )}
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="image/*"
                  onChange={handlePhotoUpload}
                  className="hidden"
                />
              </div>
              <div className="flex-1">
                <p className="text-sm text-slate-300 font-medium mb-1">Profile Photo</p>
                <p className="text-xs text-slate-500">Add a professional photo to your resume. Square images work best.</p>
                {resumeData.personalInfo.photo && (
                  <button
                    onClick={() => fileInputRef.current?.click()}
                    className="mt-2 text-xs text-emerald-400 hover:text-emerald-300"
                  >
                    Change Photo
                  </button>
                )}
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="col-span-2">
                <label className={labelClass}>Full Name</label>
                <input
                  type="text"
                  placeholder="John Doe"
                  value={resumeData.personalInfo.fullName}
                  onChange={(e) => updatePersonalInfo('fullName', e.target.value)}
                  className={inputClass}
                />
              </div>
              <div className="col-span-2">
                <label className={labelClass}>Professional Title</label>
                <input
                  type="text"
                  placeholder="Senior Software Engineer"
                  value={resumeData.personalInfo.title}
                  onChange={(e) => updatePersonalInfo('title', e.target.value)}
                  className={inputClass}
                />
              </div>
              <div>
                <label className={labelClass}>Email</label>
                <input
                  type="email"
                  placeholder="john@example.com"
                  value={resumeData.personalInfo.email}
                  onChange={(e) => updatePersonalInfo('email', e.target.value)}
                  className={inputClass}
                />
              </div>
              <div>
                <label className={labelClass}>Phone</label>
                <input
                  type="tel"
                  placeholder="+1 (555) 123-4567"
                  value={resumeData.personalInfo.phone}
                  onChange={(e) => updatePersonalInfo('phone', e.target.value)}
                  className={inputClass}
                />
              </div>
              <div>
                <label className={labelClass}>Location</label>
                <input
                  type="text"
                  placeholder="San Francisco, CA"
                  value={resumeData.personalInfo.location}
                  onChange={(e) => updatePersonalInfo('location', e.target.value)}
                  className={inputClass}
                />
              </div>
              <div>
                <label className={labelClass}>LinkedIn</label>
                <input
                  type="url"
                  placeholder="linkedin.com/in/johndoe"
                  value={resumeData.personalInfo.linkedin}
                  onChange={(e) => updatePersonalInfo('linkedin', e.target.value)}
                  className={inputClass}
                />
              </div>
              <div className="col-span-2">
                <label className={labelClass}>Website</label>
                <input
                  type="url"
                  placeholder="https://johndoe.com"
                  value={resumeData.personalInfo.website}
                  onChange={(e) => updatePersonalInfo('website', e.target.value)}
                  className={inputClass}
                />
              </div>
              <div className="col-span-2">
                <label className={labelClass}>Professional Summary</label>
                <textarea
                  placeholder="A brief summary of your professional background and career objectives..."
                  value={resumeData.personalInfo.summary}
                  onChange={(e) => updatePersonalInfo('summary', e.target.value)}
                  rows={4}
                  className={inputClass}
                />
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Experience */}
      <div className="bg-slate-900/50 rounded-2xl overflow-hidden border border-white/5">
        <SectionHeader
          section="experience"
          icon={<Briefcase className="w-5 h-5 text-white" />}
          title="Work Experience"
          count={resumeData.experiences.length}
        />
        {expandedSections.includes('experience') && (
          <div className="p-4 space-y-4">
            {resumeData.experiences.map((exp, index) => (
              <div
                key={exp.id}
                className="p-4 bg-slate-800/30 rounded-xl border border-slate-700/50 space-y-4"
              >
                <div className="flex items-center justify-between">
                  <span className="text-sm font-medium text-indigo-400">
                    Experience #{index + 1}
                  </span>
                  <button
                    onClick={() => removeExperience(exp.id)}
                    className="p-2 text-red-400 hover:bg-red-500/10 rounded-lg transition-colors"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className={labelClass}>Company</label>
                    <input
                      type="text"
                      placeholder="Company Name"
                      value={exp.company}
                      onChange={(e) =>
                        updateExperience(exp.id, 'company', e.target.value)
                      }
                      className={inputClass}
                    />
                  </div>
                  <div>
                    <label className={labelClass}>Position</label>
                    <input
                      type="text"
                      placeholder="Job Title"
                      value={exp.position}
                      onChange={(e) =>
                        updateExperience(exp.id, 'position', e.target.value)
                      }
                      className={inputClass}
                    />
                  </div>
                  <div>
                    <label className={labelClass}>Start Date</label>
                    <input
                      type="text"
                      placeholder="Jan 2020"
                      value={exp.startDate}
                      onChange={(e) =>
                        updateExperience(exp.id, 'startDate', e.target.value)
                      }
                      className={inputClass}
                    />
                  </div>
                  <div>
                    <label className={labelClass}>End Date</label>
                    <input
                      type="text"
                      placeholder="Present"
                      value={exp.endDate}
                      onChange={(e) =>
                        updateExperience(exp.id, 'endDate', e.target.value)
                      }
                      disabled={exp.current}
                      className={`${inputClass} ${exp.current ? 'opacity-50' : ''}`}
                    />
                  </div>
                  <div className="col-span-2 flex items-center gap-2">
                    <input
                      type="checkbox"
                      id={`current-${exp.id}`}
                      checked={exp.current}
                      onChange={(e) =>
                        updateExperience(exp.id, 'current', e.target.checked)
                      }
                      className="w-4 h-4 rounded border-slate-600 bg-slate-800 text-indigo-500 focus:ring-indigo-500"
                    />
                    <label
                      htmlFor={`current-${exp.id}`}
                      className="text-sm text-slate-300"
                    >
                      I currently work here
                    </label>
                  </div>
                  <div className="col-span-2">
                    <label className={labelClass}>Description</label>
                    <textarea
                      placeholder="Describe your responsibilities and achievements..."
                      value={exp.description}
                      onChange={(e) =>
                        updateExperience(exp.id, 'description', e.target.value)
                      }
                      rows={3}
                      className={inputClass}
                    />
                  </div>
                </div>
              </div>
            ))}
            <button
              onClick={addExperience}
              className="w-full py-3 border-2 border-dashed border-slate-600 rounded-xl text-slate-400 hover:border-indigo-500 hover:text-indigo-400 transition-colors flex items-center justify-center gap-2"
            >
              <Plus className="w-5 h-5" />
              Add Experience
            </button>
          </div>
        )}
      </div>

      {/* Education */}
      <div className="bg-slate-900/50 rounded-2xl overflow-hidden border border-white/5">
        <SectionHeader
          section="education"
          icon={<GraduationCap className="w-5 h-5 text-white" />}
          title="Education"
          count={resumeData.education.length}
        />
        {expandedSections.includes('education') && (
          <div className="p-4 space-y-4">
            {resumeData.education.map((edu, index) => (
              <div
                key={edu.id}
                className="p-4 bg-slate-800/30 rounded-xl border border-slate-700/50 space-y-4"
              >
                <div className="flex items-center justify-between">
                  <span className="text-sm font-medium text-indigo-400">
                    Education #{index + 1}
                  </span>
                  <button
                    onClick={() => removeEducation(edu.id)}
                    className="p-2 text-red-400 hover:bg-red-500/10 rounded-lg transition-colors"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="col-span-2">
                    <label className={labelClass}>Institution</label>
                    <input
                      type="text"
                      placeholder="University Name"
                      value={edu.institution}
                      onChange={(e) =>
                        updateEducation(edu.id, 'institution', e.target.value)
                      }
                      className={inputClass}
                    />
                  </div>
                  <div>
                    <label className={labelClass}>Degree</label>
                    <input
                      type="text"
                      placeholder="Bachelor's"
                      value={edu.degree}
                      onChange={(e) =>
                        updateEducation(edu.id, 'degree', e.target.value)
                      }
                      className={inputClass}
                    />
                  </div>
                  <div>
                    <label className={labelClass}>Field of Study</label>
                    <input
                      type="text"
                      placeholder="Computer Science"
                      value={edu.field}
                      onChange={(e) =>
                        updateEducation(edu.id, 'field', e.target.value)
                      }
                      className={inputClass}
                    />
                  </div>
                  <div>
                    <label className={labelClass}>Start Date</label>
                    <input
                      type="text"
                      placeholder="Sep 2016"
                      value={edu.startDate}
                      onChange={(e) =>
                        updateEducation(edu.id, 'startDate', e.target.value)
                      }
                      className={inputClass}
                    />
                  </div>
                  <div>
                    <label className={labelClass}>End Date</label>
                    <input
                      type="text"
                      placeholder="May 2020"
                      value={edu.endDate}
                      onChange={(e) =>
                        updateEducation(edu.id, 'endDate', e.target.value)
                      }
                      className={inputClass}
                    />
                  </div>
                  <div>
                    <label className={labelClass}>GPA (Optional)</label>
                    <input
                      type="text"
                      placeholder="3.8"
                      value={edu.gpa}
                      onChange={(e) =>
                        updateEducation(edu.id, 'gpa', e.target.value)
                      }
                      className={inputClass}
                    />
                  </div>
                </div>
              </div>
            ))}
            <button
              onClick={addEducation}
              className="w-full py-3 border-2 border-dashed border-slate-600 rounded-xl text-slate-400 hover:border-indigo-500 hover:text-indigo-400 transition-colors flex items-center justify-center gap-2"
            >
              <Plus className="w-5 h-5" />
              Add Education
            </button>
          </div>
        )}
      </div>

      {/* Skills */}
      <div className="bg-slate-900/50 rounded-2xl overflow-hidden border border-white/5">
        <SectionHeader
          section="skills"
          icon={<Wrench className="w-5 h-5 text-white" />}
          title="Skills"
          count={resumeData.skills.length}
        />
        {expandedSections.includes('skills') && (
          <div className="p-4 space-y-4">
            {resumeData.skills.map((skill, index) => (
              <div
                key={skill.id}
                className="p-4 bg-slate-800/30 rounded-xl border border-slate-700/50"
              >
                <div className="flex items-center gap-4">
                  <div className="flex-1">
                    <input
                      type="text"
                      placeholder={`Skill #${index + 1}`}
                      value={skill.name}
                      onChange={(e) =>
                        updateSkill(skill.id, 'name', e.target.value)
                      }
                      className={inputClass}
                    />
                  </div>
                  <div className="w-32">
                    <input
                      type="range"
                      min="0"
                      max="100"
                      value={skill.level}
                      onChange={(e) =>
                        updateSkill(skill.id, 'level', parseInt(e.target.value))
                      }
                      className="w-full accent-indigo-500"
                    />
                    <div className="text-center text-xs text-slate-400 mt-1">
                      {skill.level}%
                    </div>
                  </div>
                  <button
                    onClick={() => removeSkill(skill.id)}
                    className="p-2 text-red-400 hover:bg-red-500/10 rounded-lg transition-colors"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
            ))}
            <button
              onClick={addSkill}
              className="w-full py-3 border-2 border-dashed border-slate-600 rounded-xl text-slate-400 hover:border-indigo-500 hover:text-indigo-400 transition-colors flex items-center justify-center gap-2"
            >
              <Plus className="w-5 h-5" />
              Add Skill
            </button>
          </div>
        )}
      </div>

      {/* Projects */}
      <div className="bg-slate-900/50 rounded-2xl overflow-hidden border border-white/5">
        <SectionHeader
          section="projects"
          icon={<FolderOpen className="w-5 h-5 text-white" />}
          title="Projects"
          count={resumeData.projects.length}
        />
        {expandedSections.includes('projects') && (
          <div className="p-4 space-y-4">
            {resumeData.projects.map((project, index) => (
              <div
                key={project.id}
                className="p-4 bg-slate-800/30 rounded-xl border border-slate-700/50 space-y-4"
              >
                <div className="flex items-center justify-between">
                  <span className="text-sm font-medium text-indigo-400">
                    Project #{index + 1}
                  </span>
                  <button
                    onClick={() => removeProject(project.id)}
                    className="p-2 text-red-400 hover:bg-red-500/10 rounded-lg transition-colors"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className={labelClass}>Project Name</label>
                    <input
                      type="text"
                      placeholder="Project Name"
                      value={project.name}
                      onChange={(e) =>
                        updateProject(project.id, 'name', e.target.value)
                      }
                      className={inputClass}
                    />
                  </div>
                  <div>
                    <label className={labelClass}>Link (Optional)</label>
                    <input
                      type="url"
                      placeholder="https://github.com/..."
                      value={project.link}
                      onChange={(e) =>
                        updateProject(project.id, 'link', e.target.value)
                      }
                      className={inputClass}
                    />
                  </div>
                  <div className="col-span-2">
                    <label className={labelClass}>Technologies Used</label>
                    <input
                      type="text"
                      placeholder="React, Node.js, PostgreSQL"
                      value={project.technologies}
                      onChange={(e) =>
                        updateProject(project.id, 'technologies', e.target.value)
                      }
                      className={inputClass}
                    />
                  </div>
                  <div className="col-span-2">
                    <label className={labelClass}>Description</label>
                    <textarea
                      placeholder="Describe the project..."
                      value={project.description}
                      onChange={(e) =>
                        updateProject(project.id, 'description', e.target.value)
                      }
                      rows={3}
                      className={inputClass}
                    />
                  </div>
                </div>
              </div>
            ))}
            <button
              onClick={addProject}
              className="w-full py-3 border-2 border-dashed border-slate-600 rounded-xl text-slate-400 hover:border-indigo-500 hover:text-indigo-400 transition-colors flex items-center justify-center gap-2"
            >
              <Plus className="w-5 h-5" />
              Add Project
            </button>
          </div>
        )}
      </div>

      {/* Custom Fields */}
      <div className="bg-slate-900/50 rounded-2xl overflow-hidden border border-white/5">
        <SectionHeader
          section="custom"
          icon={<Layers className="w-5 h-5 text-white" />}
          title="Custom Sections"
          count={resumeData.customFields.length}
        />
        {expandedSections.includes('custom') && (
          <div className="p-4 space-y-4">
            {/* Info banner */}
            {resumeData.customFields.length === 0 && (
              <div className="p-4 bg-indigo-500/10 border border-indigo-500/20 rounded-xl">
                <div className="flex items-start gap-3">
                  <Pencil className="w-5 h-5 text-indigo-400 mt-0.5 flex-shrink-0" />
                  <div>
                    <p className="text-sm text-indigo-300 font-medium">Add Custom Sections</p>
                    <p className="text-xs text-slate-400 mt-1">
                      Create your own sections like Languages, Certifications, Awards, Volunteer Work, Hobbies, References, Publications, or anything else you need.
                    </p>
                  </div>
                </div>
              </div>
            )}

            {/* Custom sections list */}
            {resumeData.customFields.map((section, sectionIndex) => (
              <div
                key={section.id}
                className="p-4 bg-slate-800/30 rounded-xl border border-amber-500/20 space-y-4"
              >
                {/* Section header */}
                <div className="flex items-center gap-3">
                  <div className="flex-1">
                    <label className="block text-xs font-medium text-amber-400 mb-1.5">
                      Section Title #{sectionIndex + 1}
                    </label>
                    <input
                      type="text"
                      placeholder="e.g., Languages, Certifications, Awards..."
                      value={section.sectionTitle}
                      onChange={(e) => updateCustomSectionTitle(section.id, e.target.value)}
                      className="w-full px-4 py-3 bg-slate-800/50 border border-amber-500/30 rounded-xl text-white placeholder-slate-500 focus:outline-none focus:border-amber-400 focus:ring-1 focus:ring-amber-400 transition-colors text-sm font-semibold"
                    />
                  </div>
                  <button
                    onClick={() => removeCustomSection(section.id)}
                    className="p-2 text-red-400 hover:bg-red-500/10 rounded-lg transition-colors mt-6"
                    title="Remove section"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>

                {/* Items */}
                {section.items.map((item, itemIndex) => (
                  <div
                    key={item.id}
                    className="ml-2 p-3 bg-slate-900/50 rounded-lg border border-slate-700/50 space-y-3"
                  >
                    <div className="flex items-center justify-between">
                      <span className="text-xs text-slate-500">Item #{itemIndex + 1}</span>
                      <button
                        onClick={() => removeCustomItem(section.id, item.id)}
                        className="p-1.5 text-red-400 hover:bg-red-500/10 rounded-md transition-colors"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <label className="block text-xs text-slate-400 mb-1">Title *</label>
                        <input
                          type="text"
                          placeholder="e.g., English, AWS Cert..."
                          value={item.title}
                          onChange={(e) => updateCustomItem(section.id, item.id, 'title', e.target.value)}
                          className={inputClass}
                        />
                      </div>
                      <div>
                        <label className="block text-xs text-slate-400 mb-1">Subtitle (optional)</label>
                        <input
                          type="text"
                          placeholder="e.g., Native, Amazon..."
                          value={item.subtitle || ''}
                          onChange={(e) => updateCustomItem(section.id, item.id, 'subtitle', e.target.value)}
                          className={inputClass}
                        />
                      </div>
                      <div className="col-span-2">
                        <label className="block text-xs text-slate-400 mb-1">Description (optional)</label>
                        <input
                          type="text"
                          placeholder="e.g., Issued Dec 2022, Fluent..."
                          value={item.description || ''}
                          onChange={(e) => updateCustomItem(section.id, item.id, 'description', e.target.value)}
                          className={inputClass}
                        />
                      </div>
                    </div>
                  </div>
                ))}

                <button
                  onClick={() => addCustomItem(section.id)}
                  className="w-full py-2.5 border border-dashed border-slate-600 rounded-lg text-slate-400 hover:border-amber-500 hover:text-amber-400 transition-colors flex items-center justify-center gap-2 text-sm"
                >
                  <Plus className="w-4 h-4" />
                  Add Item to "{section.sectionTitle || 'Untitled'}"
                </button>
              </div>
            ))}

            {/* Add new section button */}
            <button
              onClick={addCustomSection}
              className="w-full py-3 border-2 border-dashed border-amber-500/40 rounded-xl text-amber-400 hover:border-amber-400 hover:bg-amber-500/10 transition-colors flex items-center justify-center gap-2"
            >
              <Plus className="w-5 h-5" />
              Add Custom Section
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

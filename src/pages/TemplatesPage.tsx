import { useNavigate } from 'react-router-dom';
import { ArrowLeft, Check, FileText, Star, Users, Briefcase, Code, Sparkles } from 'lucide-react';
import { templates } from '../data/templates';
import { useResume } from '../context/ResumeContext';
import { Template } from '../types/resume';

export function TemplatesPage() {
  const navigate = useNavigate();
  const { selectedTemplate, setSelectedTemplate } = useResume();

  const handleSelectTemplate = (template: Template) => {
    setSelectedTemplate(template);
  };

  const handleContinue = () => {
    if (selectedTemplate) {
      navigate('/editor');
    }
  };

  const getTemplateIcon = (templateId: string) => {
    switch (templateId) {
      case 'modern': return <Briefcase className="w-4 h-4" />;
      case 'minimal': return <Sparkles className="w-4 h-4" />;
      case 'creative': return <Sparkles className="w-4 h-4" />;
      case 'executive': return <Users className="w-4 h-4" />;
      case 'tech': return <Code className="w-4 h-4" />;
      default: return <FileText className="w-4 h-4" />;
    }
  };

  const getTemplatePreview = (templateId: string) => {
    switch (templateId) {
      case 'modern':
        return (
          <div className="h-full flex text-[6px] leading-tight">
            {/* Left Sidebar */}
            <div className="w-[72px] bg-slate-800 p-2.5 text-white">
              <img 
                src="https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&crop=face" 
                className="w-10 h-10 mx-auto rounded-full border-2 border-blue-400 mb-2 object-cover"
                alt=""
              />
              <div className="text-center mb-3">
                <div className="text-[5px] text-blue-400 font-semibold mb-1">CONTACT</div>
                <div className="text-[4px] text-slate-300 space-y-0.5">
                  <div>📧 john@email.com</div>
                  <div>📱 (555) 123-4567</div>
                  <div>📍 New York, NY</div>
                </div>
              </div>
              <div className="mb-3">
                <div className="text-[5px] text-blue-400 font-semibold mb-1">SKILLS</div>
                <div className="space-y-1">
                  <div>
                    <div className="text-[4px] text-slate-300 mb-0.5">JavaScript</div>
                    <div className="h-1 bg-slate-700 rounded-full"><div className="h-1 bg-blue-400 rounded-full w-[90%]"></div></div>
                  </div>
                  <div>
                    <div className="text-[4px] text-slate-300 mb-0.5">React</div>
                    <div className="h-1 bg-slate-700 rounded-full"><div className="h-1 bg-blue-400 rounded-full w-[85%]"></div></div>
                  </div>
                  <div>
                    <div className="text-[4px] text-slate-300 mb-0.5">Node.js</div>
                    <div className="h-1 bg-slate-700 rounded-full"><div className="h-1 bg-blue-400 rounded-full w-[80%]"></div></div>
                  </div>
                </div>
              </div>
              <div>
                <div className="text-[5px] text-blue-400 font-semibold mb-1">EDUCATION</div>
                <div className="text-[4px] text-slate-300">
                  <div className="font-medium text-white">MIT</div>
                  <div>BS Computer Science</div>
                  <div className="text-slate-400">2016 - 2020</div>
                </div>
              </div>
            </div>
            {/* Right Content */}
            <div className="flex-1 bg-white p-3">
              <div className="border-b-2 border-blue-500 pb-1.5 mb-2">
                <div className="text-[10px] font-bold text-slate-800">John Anderson</div>
                <div className="text-[6px] text-blue-600 font-medium">Senior Software Engineer</div>
              </div>
              <div className="text-[4px] text-slate-600 mb-2 leading-relaxed">
                Innovative software engineer with 8+ years of experience building scalable web applications. 
                Passionate about clean code and modern technologies.
              </div>
              <div className="mb-2">
                <div className="text-[5px] font-bold text-slate-800 border-b border-slate-200 pb-0.5 mb-1">EXPERIENCE</div>
                <div className="mb-1.5">
                  <div className="flex justify-between">
                    <span className="font-semibold text-slate-700">Senior Engineer</span>
                    <span className="text-slate-400 text-[4px]">2021 - Present</span>
                  </div>
                  <div className="text-blue-600 text-[4px]">Google Inc.</div>
                  <div className="text-[4px] text-slate-500 mt-0.5">• Led team of 5 engineers on core platform</div>
                </div>
                <div>
                  <div className="flex justify-between">
                    <span className="font-semibold text-slate-700">Software Engineer</span>
                    <span className="text-slate-400 text-[4px]">2018 - 2021</span>
                  </div>
                  <div className="text-blue-600 text-[4px]">Meta Platforms</div>
                  <div className="text-[4px] text-slate-500 mt-0.5">• Built React components for 1M+ users</div>
                </div>
              </div>
            </div>
          </div>
        );
      case 'minimal':
        return (
          <div className="h-full bg-white p-4 text-[6px] leading-tight">
            <div className="text-center pb-3 border-b border-gray-200 mb-3">
              <div className="flex items-center justify-center gap-2 mb-1.5">
                <img 
                  src="https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop&crop=face" 
                  className="w-10 h-10 rounded-full object-cover grayscale"
                  alt=""
                />
                <div className="text-left">
                  <div className="text-[11px] font-light text-gray-800 tracking-widest">SARAH MILLER</div>
                  <div className="text-[6px] text-gray-500 italic">Creative Director</div>
                </div>
              </div>
              <div className="flex justify-center gap-3 text-[4px] text-gray-400">
                <span>sarah@design.co</span>
                <span>•</span>
                <span>Los Angeles, CA</span>
                <span>•</span>
                <span>(555) 987-6543</span>
              </div>
            </div>
            <div className="text-[4px] text-gray-600 text-center mb-3 italic leading-relaxed px-4">
              "Award-winning creative director with 10+ years transforming brands through innovative design strategies and compelling visual storytelling."
            </div>
            <div className="mb-2.5">
              <div className="text-[5px] text-gray-400 tracking-[0.2em] mb-1 text-center">EXPERIENCE</div>
              <div className="text-center">
                <div className="font-medium text-gray-800">Creative Director</div>
                <div className="text-gray-500 text-[5px]">Apple Inc. • 2019 - Present</div>
              </div>
            </div>
            <div className="mb-2.5">
              <div className="text-[5px] text-gray-400 tracking-[0.2em] mb-1 text-center">EDUCATION</div>
              <div className="text-center">
                <div className="font-medium text-gray-800">MFA Design</div>
                <div className="text-gray-500 text-[5px]">Rhode Island School of Design</div>
              </div>
            </div>
            <div>
              <div className="text-[5px] text-gray-400 tracking-[0.2em] mb-1 text-center">EXPERTISE</div>
              <div className="flex justify-center gap-1.5 flex-wrap">
                <span className="px-1.5 py-0.5 bg-gray-100 text-gray-600 rounded text-[4px]">Brand Strategy</span>
                <span className="px-1.5 py-0.5 bg-gray-100 text-gray-600 rounded text-[4px]">UI/UX</span>
                <span className="px-1.5 py-0.5 bg-gray-100 text-gray-600 rounded text-[4px]">Motion</span>
              </div>
            </div>
          </div>
        );
      case 'creative':
        return (
          <div className="h-full bg-[#fefefe] text-[6px] leading-tight relative overflow-hidden">
            {/* Decorative Elements */}
            <div className="absolute top-0 right-0 w-16 h-16 bg-gradient-to-br from-pink-200 to-purple-200 rounded-bl-full opacity-60" />
            <div className="absolute bottom-0 left-0 w-12 h-12 bg-gradient-to-tr from-blue-200 to-pink-200 rounded-tr-full opacity-50" />
            
            {/* Header */}
            <div className="p-3 relative z-10">
              <div className="flex items-start gap-2.5">
                <div className="relative">
                  <div className="absolute -top-0.5 -left-0.5 w-[50px] h-[50px] rounded-xl bg-gradient-to-br from-pink-400 via-purple-400 to-blue-400 rotate-3" />
                  <img 
                    src="https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100&h=100&fit=crop&crop=face" 
                    className="w-11 h-11 rounded-lg object-cover relative z-10 border-2 border-white"
                    alt=""
                  />
                </div>
                <div className="flex-1">
                  <div className="text-[11px] font-extrabold bg-gradient-to-r from-pink-500 via-purple-500 to-blue-500 text-transparent bg-clip-text">Alex Rivera</div>
                  <div className="text-[6px] text-gray-500">Visual Designer & Artist</div>
                  <div className="flex gap-1.5 mt-1.5 text-[4px]">
                    <span className="px-1.5 py-0.5 bg-pink-50 text-pink-600 rounded-full">✉️ alex@creative.io</span>
                    <span className="px-1.5 py-0.5 bg-purple-50 text-purple-600 rounded-full">📍 Miami, FL</span>
                  </div>
                </div>
              </div>
            </div>
            
            {/* Summary */}
            <div className="px-3 relative z-10">
              <div className="bg-gradient-to-r from-pink-50 via-purple-50 to-blue-50 rounded-lg p-2 mb-2.5">
                <div className="text-[4px] text-gray-600 leading-relaxed italic">
                  "Creative designer crafting memorable brand experiences through vibrant visuals and innovative storytelling."
                </div>
              </div>
            </div>

            {/* Content */}
            <div className="px-3 flex gap-2.5 relative z-10">
              <div className="w-[70px]">
                <div className="flex items-center gap-1 mb-1">
                  <div className="w-2 h-0.5 bg-gradient-to-r from-pink-400 to-purple-400 rounded" />
                  <div className="text-[5px] font-bold text-pink-500">SKILLS</div>
                </div>
                <div className="flex flex-wrap gap-0.5 mb-2.5">
                  <span className="px-1 py-0.5 bg-pink-50 text-pink-600 rounded text-[4px]">Figma</span>
                  <span className="px-1 py-0.5 bg-purple-50 text-purple-600 rounded text-[4px]">Illustrator</span>
                  <span className="px-1 py-0.5 bg-blue-50 text-blue-600 rounded text-[4px]">Motion</span>
                  <span className="px-1 py-0.5 bg-green-50 text-green-600 rounded text-[4px]">3D</span>
                </div>
                <div className="flex items-center gap-1 mb-1">
                  <div className="w-2 h-0.5 bg-gradient-to-r from-purple-400 to-blue-400 rounded" />
                  <div className="text-[5px] font-bold text-purple-500">EDUCATION</div>
                </div>
                <div className="p-1.5 bg-purple-50 rounded-lg text-[4px]">
                  <div className="font-semibold text-gray-800">BFA Visual Arts</div>
                  <div className="text-purple-500">Parsons School</div>
                  <div className="text-gray-400 mt-0.5">2014 - 2018</div>
                </div>
              </div>
              <div className="flex-1">
                <div className="flex items-center gap-1 mb-1">
                  <div className="w-2 h-0.5 bg-gradient-to-r from-pink-400 to-pink-300 rounded" />
                  <div className="text-[5px] font-bold text-pink-500">EXPERIENCE</div>
                </div>
                <div className="relative pl-2 mb-1.5">
                  <div className="absolute left-0 top-1 w-1 h-1 rounded-full bg-gradient-to-br from-pink-400 to-purple-400" />
                  <div className="flex justify-between items-start">
                    <div>
                      <div className="font-semibold text-gray-800">Lead Designer</div>
                      <div className="text-purple-500">Spotify</div>
                    </div>
                    <span className="text-[4px] text-white bg-gradient-to-r from-pink-400 to-purple-400 px-1.5 py-0.5 rounded-full">2022-Now</span>
                  </div>
                  <div className="text-gray-500 text-[4px] mt-0.5">Brand & marketing design lead</div>
                </div>
                <div className="relative pl-2">
                  <div className="absolute left-0 top-1 w-1 h-1 rounded-full bg-gradient-to-br from-purple-400 to-blue-400" />
                  <div className="flex justify-between items-start">
                    <div>
                      <div className="font-semibold text-gray-800">Senior Designer</div>
                      <div className="text-blue-500">Instagram</div>
                    </div>
                    <span className="text-[4px] text-gray-400">2019-2022</span>
                  </div>
                </div>
                <div className="flex items-center gap-1 mt-2.5 mb-1">
                  <div className="w-2 h-0.5 bg-gradient-to-r from-purple-400 to-blue-400 rounded" />
                  <div className="text-[5px] font-bold text-purple-500">PROJECTS</div>
                </div>
                <div className="flex gap-1">
                  <div className="flex-1 p-1.5 bg-gradient-to-br from-pink-50 to-purple-50 rounded-lg">
                    <div className="font-semibold text-gray-800 text-[5px]">Brand Kit</div>
                    <div className="text-purple-500 text-[3px]">Figma • Illustrator</div>
                  </div>
                  <div className="flex-1 p-1.5 bg-gradient-to-br from-purple-50 to-blue-50 rounded-lg">
                    <div className="font-semibold text-gray-800 text-[5px]">Motion</div>
                    <div className="text-blue-500 text-[3px]">After Effects</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        );
      case 'executive':
        return (
          <div className="h-full bg-white text-[6px] leading-tight">
            <div className="border-b-4 border-teal-600 p-3 flex items-center gap-2.5 bg-gradient-to-r from-slate-50 to-white">
              <img 
                src="https://images.unsplash.com/photo-1560250097-0b93528c311a?w=100&h=100&fit=crop&crop=face" 
                className="w-11 h-11 rounded object-cover border border-gray-200"
                alt=""
              />
              <div className="flex-1">
                <div className="text-[10px] font-bold text-teal-800">Michael Chen</div>
                <div className="text-[6px] text-gray-600">Chief Executive Officer</div>
              </div>
              <div className="text-right text-[4px] text-gray-500">
                <div>m.chen@corp.com</div>
                <div>(555) 234-5678</div>
                <div>San Francisco, CA</div>
              </div>
            </div>
            <div className="p-3 space-y-2">
              <div className="border-b border-gray-200 pb-1.5">
                <div className="text-[5px] font-bold text-teal-700 tracking-wide mb-0.5">EXECUTIVE SUMMARY</div>
                <div className="text-[4px] text-gray-600 leading-relaxed">
                  Visionary executive with 15+ years driving organizational growth and digital transformation. 
                  Proven track record of scaling companies from startup to IPO.
                </div>
              </div>
              <div className="border-b border-gray-200 pb-1.5">
                <div className="text-[5px] font-bold text-teal-700 tracking-wide mb-0.5">EXPERIENCE</div>
                <div className="flex justify-between items-start">
                  <div>
                    <div className="font-semibold text-gray-800">Chief Executive Officer</div>
                    <div className="text-teal-600 text-[5px]">TechCorp International</div>
                  </div>
                  <div className="text-[4px] text-gray-400">2020 - Present</div>
                </div>
                <div className="text-[4px] text-gray-500 mt-0.5">• Grew revenue from $50M to $200M in 3 years</div>
              </div>
              <div className="grid grid-cols-2 gap-2">
                <div>
                  <div className="text-[5px] font-bold text-teal-700 tracking-wide mb-0.5">EDUCATION</div>
                  <div className="text-[5px] font-medium text-gray-800">MBA, Harvard Business</div>
                  <div className="text-[4px] text-gray-500">BS Engineering, Stanford</div>
                </div>
                <div>
                  <div className="text-[5px] font-bold text-teal-700 tracking-wide mb-0.5">EXPERTISE</div>
                  <div className="text-[4px] text-gray-600 space-y-0.5">
                    <div className="flex items-center gap-1"><span className="w-1 h-1 bg-teal-500 rounded-full"></span> Strategic Planning</div>
                    <div className="flex items-center gap-1"><span className="w-1 h-1 bg-teal-500 rounded-full"></span> M&A Leadership</div>
                    <div className="flex items-center gap-1"><span className="w-1 h-1 bg-teal-500 rounded-full"></span> Board Relations</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        );
      case 'tech':
        return (
          <div className="h-full bg-slate-900 p-3 text-[6px] leading-tight">
            <div className="flex items-center gap-2.5 mb-2.5 pb-2 border-b border-slate-700">
              <img 
                src="https://images.unsplash.com/photo-1531427186611-ecfd6d936c79?w=100&h=100&fit=crop&crop=face" 
                className="w-10 h-10 rounded-lg border-2 border-cyan-400 object-cover"
                alt=""
              />
              <div className="flex-1">
                <div className="text-[9px] font-bold text-white font-mono">David_Kim</div>
                <div className="text-[5px] text-cyan-400 font-mono">// Full Stack Developer</div>
              </div>
              <div className="text-[4px] text-slate-500 font-mono text-right">
                <div className="text-cyan-400">david@dev.io</div>
                <div>github.com/dkim</div>
              </div>
            </div>
            <div className="flex gap-2">
              <div className="w-[60px]">
                <div className="text-[5px] text-cyan-400 font-mono mb-1">&lt;skills/&gt;</div>
                <div className="space-y-0.5">
                  <div className="px-1 py-0.5 bg-slate-800 border border-slate-700 rounded text-[4px] text-slate-300 font-mono">TypeScript</div>
                  <div className="px-1 py-0.5 bg-slate-800 border border-slate-700 rounded text-[4px] text-slate-300 font-mono">React</div>
                  <div className="px-1 py-0.5 bg-slate-800 border border-slate-700 rounded text-[4px] text-slate-300 font-mono">Node.js</div>
                  <div className="px-1 py-0.5 bg-slate-800 border border-slate-700 rounded text-[4px] text-slate-300 font-mono">PostgreSQL</div>
                  <div className="px-1 py-0.5 bg-slate-800 border border-slate-700 rounded text-[4px] text-slate-300 font-mono">AWS</div>
                </div>
                <div className="text-[5px] text-cyan-400 font-mono mt-2 mb-1">&lt;edu/&gt;</div>
                <div className="text-[4px] text-slate-400">
                  <div className="text-white">Stanford</div>
                  <div>MS CS '19</div>
                </div>
              </div>
              <div className="flex-1 space-y-1.5">
                <div className="bg-slate-800/80 rounded p-1.5 border border-slate-700">
                  <div className="text-[5px] text-cyan-400 font-mono mb-0.5">&lt;experience&gt;</div>
                  <div className="flex justify-between">
                    <span className="text-white font-medium">Senior SWE</span>
                    <span className="text-slate-500 text-[4px]">2021-Now</span>
                  </div>
                  <div className="text-cyan-400/70 text-[4px]">Netflix • Platform Team</div>
                  <div className="text-slate-400 text-[4px] mt-0.5">Built streaming infra serving 200M users</div>
                </div>
                <div className="bg-slate-800/80 rounded p-1.5 border border-slate-700">
                  <div className="text-[5px] text-cyan-400 font-mono mb-0.5">&lt;projects&gt;</div>
                  <div className="text-white font-medium">DevFlow</div>
                  <div className="text-slate-400 text-[4px]">Open source CI/CD tool • 5k+ ⭐</div>
                  <div className="flex gap-1 mt-0.5">
                    <span className="px-1 py-0.5 bg-cyan-900/50 rounded text-[3px] text-cyan-300">Go</span>
                    <span className="px-1 py-0.5 bg-cyan-900/50 rounded text-[3px] text-cyan-300">K8s</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        );
      default:
        return null;
    }
  };

  const getBestFor = (templateId: string) => {
    switch (templateId) {
      case 'modern': return 'Business, Marketing, Finance';
      case 'minimal': return 'Design, Writing, Academia';
      case 'creative': return 'Art, Design, Media';
      case 'executive': return 'Management, Consulting, Law';
      case 'tech': return 'Software, IT, Engineering';
      default: return '';
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-950 via-slate-900 to-emerald-950">
      {/* Header */}
      <header className="sticky top-0 z-50 bg-slate-950/80 backdrop-blur-xl border-b border-white/5">
        <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
          <button
            onClick={() => navigate('/')}
            className="flex items-center gap-2 text-slate-400 hover:text-white transition-colors"
          >
            <ArrowLeft className="w-5 h-5" />
            <span>Back</span>
          </button>
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center">
              <FileText className="w-4 h-4 text-white" />
            </div>
            <span className="text-lg font-bold text-white">ResumeForge</span>
          </div>
          <button
            onClick={handleContinue}
            disabled={!selectedTemplate}
            className={`px-6 py-2.5 rounded-full font-medium transition-all ${
              selectedTemplate
                ? 'bg-gradient-to-r from-emerald-500 to-teal-600 text-white hover:shadow-lg hover:shadow-emerald-500/25 hover:-translate-y-0.5'
                : 'bg-slate-700 text-slate-400 cursor-not-allowed'
            }`}
          >
            Continue
          </button>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-6 py-12">
        <div className="text-center mb-12">
          <h1 className="text-4xl md:text-5xl font-bold text-white mb-4">
            Choose Your Template
          </h1>
          <p className="text-xl text-slate-400">
            Select a professionally designed template that matches your style
          </p>
        </div>

        {/* Templates Grid */}
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
          {templates.map((template) => (
            <div
              key={template.id}
              onClick={() => handleSelectTemplate(template)}
              className={`group cursor-pointer transition-all duration-300 ${
                selectedTemplate?.id === template.id
                  ? 'scale-[1.02]'
                  : 'hover:scale-[1.02]'
              }`}
            >
              <div
                className={`relative bg-gradient-to-br from-slate-800/50 to-slate-900/50 rounded-2xl border-2 overflow-hidden transition-all ${
                  selectedTemplate?.id === template.id
                    ? 'border-emerald-500 shadow-xl shadow-emerald-500/20'
                    : 'border-white/5 hover:border-white/20'
                }`}
              >
                {/* Selection Indicator */}
                {selectedTemplate?.id === template.id && (
                  <div className="absolute top-4 right-4 z-10 w-8 h-8 bg-emerald-500 rounded-full flex items-center justify-center shadow-lg">
                    <Check className="w-5 h-5 text-white" />
                  </div>
                )}

                {/* Popular Badge */}
                {template.id === 'modern' && (
                  <div className="absolute top-4 left-4 z-10 flex items-center gap-1 px-3 py-1 bg-gradient-to-r from-amber-500 to-orange-500 rounded-full text-xs font-semibold text-white">
                    <Star className="w-3 h-3 fill-current" />
                    Popular
                  </div>
                )}

                {/* Template Preview */}
                <div className="h-64 overflow-hidden rounded-t-xl m-1">
                  {getTemplatePreview(template.id)}
                </div>

                {/* Template Info */}
                <div className="p-5 bg-slate-900/50">
                  <div className="flex items-center gap-2 mb-2">
                    <div 
                      className="w-8 h-8 rounded-lg flex items-center justify-center text-white"
                      style={{ backgroundColor: template.colors.primary }}
                    >
                      {getTemplateIcon(template.id)}
                    </div>
                    <h3 className="text-lg font-semibold text-white">
                      {template.name}
                    </h3>
                  </div>
                  <p className="text-slate-400 text-sm mb-3">{template.description}</p>
                  
                  {/* Best For */}
                  <div className="flex items-center gap-2 text-xs">
                    <span className="text-slate-500">Best for:</span>
                    <span className="text-slate-300">{getBestFor(template.id)}</span>
                  </div>
                  
                  {/* Color Preview */}
                  <div className="flex items-center gap-2 mt-3 pt-3 border-t border-white/5">
                    <span className="text-xs text-slate-500">Theme:</span>
                    <div className="flex gap-1.5">
                      <div
                        className="w-5 h-5 rounded-full ring-2 ring-white/10"
                        style={{ backgroundColor: template.colors.primary }}
                      />
                      <div
                        className="w-5 h-5 rounded-full ring-2 ring-white/10"
                        style={{ backgroundColor: template.colors.secondary }}
                      />
                      <div
                        className="w-5 h-5 rounded-full ring-2 ring-white/10"
                        style={{ backgroundColor: template.colors.accent }}
                      />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>

        {/* Bottom CTA */}
        <div className="text-center mt-16">
          <button
            onClick={handleContinue}
            disabled={!selectedTemplate}
            className={`px-10 py-4 rounded-full font-semibold text-lg transition-all ${
              selectedTemplate
                ? 'bg-gradient-to-r from-emerald-500 to-teal-600 text-white hover:shadow-xl hover:shadow-emerald-500/30 hover:-translate-y-1'
                : 'bg-slate-700 text-slate-400 cursor-not-allowed'
            }`}
          >
            {selectedTemplate ? `Continue with ${selectedTemplate.name}` : 'Select a Template'}
          </button>
        </div>
      </main>
    </div>
  );
}

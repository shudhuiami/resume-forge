import { useNavigate } from 'react-router-dom';
import { Sparkles, FileText, Palette, Download, Zap, Shield, Clock, ArrowRight, CheckCircle2 } from 'lucide-react';

export function LandingPage() {
  const navigate = useNavigate();

  const features = [
    {
      icon: <Palette className="w-6 h-6" />,
      title: 'Beautiful Templates',
      description: 'Choose from 20+ professionally designed templates crafted to impress recruiters.',
    },
    {
      icon: <Zap className="w-6 h-6" />,
      title: 'Real-time Preview',
      description: 'See your changes instantly as you type with our live preview feature.',
    },
    {
      icon: <Download className="w-6 h-6" />,
      title: 'PDF Export',
      description: 'Download your resume in high-quality PDF format, ready to share.',
    },
    {
      icon: <Shield className="w-6 h-6" />,
      title: 'ATS-Friendly',
      description: 'All templates are optimized for Applicant Tracking Systems.',
    },
    {
      icon: <Clock className="w-6 h-6" />,
      title: 'Quick & Easy',
      description: 'Build a professional resume in minutes, not hours.',
    },
    {
      icon: <Sparkles className="w-6 h-6" />,
      title: 'Custom Sections',
      description: 'Add custom fields for languages, certifications, and more.',
    },
  ];

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-950 via-slate-900 to-emerald-950">
      {/* Navbar */}
      <nav className="fixed top-0 left-0 right-0 z-50 bg-slate-950/80 backdrop-blur-xl border-b border-white/5">
        <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center">
              <FileText className="w-5 h-5 text-white" />
            </div>
            <span className="text-xl font-bold text-white">ResumeForge</span>
          </div>
          <div className="hidden md:flex items-center gap-8">
            <a href="#features" className="text-slate-400 hover:text-white transition-colors">Features</a>
            <a href="#templates" className="text-slate-400 hover:text-white transition-colors">Templates</a>
          </div>
          <button
            onClick={() => navigate('/templates')}
            className="px-5 py-2.5 bg-gradient-to-r from-emerald-500 to-teal-600 text-white rounded-full font-medium hover:shadow-lg hover:shadow-emerald-500/25 transition-all hover:-translate-y-0.5"
          >
            Get Started
          </button>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="pt-32 pb-20 px-6">
        <div className="max-w-7xl mx-auto">
          <div className="text-center max-w-4xl mx-auto">
            <div className="inline-flex items-center gap-2 px-4 py-2 bg-emerald-500/10 rounded-full border border-emerald-500/20 mb-8">
              <Sparkles className="w-4 h-4 text-amber-400" />
              <span className="text-sm text-emerald-300">Build your perfect resume in minutes</span>
            </div>
            <h1 className="text-5xl md:text-7xl font-bold text-white mb-6 leading-tight">
              Create Stunning
              <span className="bg-gradient-to-r from-emerald-400 via-teal-400 to-amber-400 bg-clip-text text-transparent"> Resumes </span>
              That Get You Hired
            </h1>
            <p className="text-xl text-slate-400 mb-10 max-w-2xl mx-auto">
              Stand out from the crowd with professionally designed templates. Easy to use, real-time preview, and instant PDF export.
            </p>
            <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
              <button
                onClick={() => navigate('/templates')}
                className="w-full sm:w-auto px-8 py-4 bg-gradient-to-r from-emerald-500 to-teal-600 text-white rounded-full font-semibold text-lg hover:shadow-xl hover:shadow-emerald-500/30 transition-all hover:-translate-y-1 flex items-center justify-center gap-2"
              >
                Start Building Free
                <ArrowRight className="w-5 h-5" />
              </button>
              <button 
                onClick={() => navigate('/templates')}
                className="w-full sm:w-auto px-8 py-4 bg-white/5 text-white rounded-full font-semibold text-lg border border-white/10 hover:bg-white/10 transition-all"
              >
                View Templates
              </button>
            </div>
            <div className="flex flex-wrap items-center justify-center gap-6 md:gap-8 mt-12 text-slate-400">
              <div className="flex items-center gap-2">
                <CheckCircle2 className="w-5 h-5 text-emerald-400" />
                <span>Free to use</span>
              </div>
              <div className="flex items-center gap-2">
                <CheckCircle2 className="w-5 h-5 text-emerald-400" />
                <span>No signup required</span>
              </div>
              <div className="flex items-center gap-2">
                <CheckCircle2 className="w-5 h-5 text-emerald-400" />
                <span>PDF export</span>
              </div>
            </div>
          </div>

          {/* Hero Image/Preview */}
          <div className="mt-20 relative">
            <div className="absolute inset-0 bg-gradient-to-t from-slate-950 via-transparent to-transparent z-10 pointer-events-none" />
            <div className="relative bg-gradient-to-br from-slate-800/50 to-slate-900/50 rounded-3xl border border-white/10 p-4 md:p-8 backdrop-blur-xl">
              <div className="grid md:grid-cols-2 gap-6">
                {/* Editor Panel */}
                <div className="bg-slate-900 rounded-2xl p-6 border border-white/5">
                  <div className="flex items-center gap-2 mb-6">
                    <div className="w-3 h-3 rounded-full bg-red-500" />
                    <div className="w-3 h-3 rounded-full bg-yellow-500" />
                    <div className="w-3 h-3 rounded-full bg-green-500" />
                    <span className="ml-2 text-sm text-slate-500">Resume Editor</span>
                  </div>
                  <div className="space-y-4">
                    <div>
                      <div className="text-xs text-emerald-400 mb-1">Personal Information</div>
                      <div className="bg-slate-800 rounded-lg p-3 border border-slate-700">
                        <div className="flex items-center gap-3 mb-2">
                          <div className="w-12 h-12 rounded-full bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center text-white text-sm font-bold">JA</div>
                          <div className="flex-1">
                            <div className="h-4 bg-slate-700 rounded w-32 mb-1" />
                            <div className="h-3 bg-slate-700/50 rounded w-40" />
                          </div>
                        </div>
                      </div>
                    </div>
                    <div>
                      <div className="text-xs text-emerald-400 mb-1">Experience</div>
                      <div className="bg-slate-800 rounded-lg p-3 border border-slate-700 space-y-2">
                        <div className="flex gap-2">
                          <div className="w-8 h-8 rounded bg-blue-500/20 flex items-center justify-center text-blue-400 text-xs">G</div>
                          <div className="flex-1">
                            <div className="h-3 bg-slate-700 rounded w-28 mb-1" />
                            <div className="h-2 bg-slate-700/50 rounded w-20" />
                          </div>
                        </div>
                        <div className="flex gap-2">
                          <div className="w-8 h-8 rounded bg-purple-500/20 flex items-center justify-center text-purple-400 text-xs">M</div>
                          <div className="flex-1">
                            <div className="h-3 bg-slate-700 rounded w-24 mb-1" />
                            <div className="h-2 bg-slate-700/50 rounded w-16" />
                          </div>
                        </div>
                      </div>
                    </div>
                    <div>
                      <div className="text-xs text-emerald-400 mb-1">Skills</div>
                      <div className="flex flex-wrap gap-2">
                        <span className="px-3 py-1 bg-emerald-500/20 text-emerald-300 rounded-full text-xs">React</span>
                        <span className="px-3 py-1 bg-teal-500/20 text-teal-300 rounded-full text-xs">TypeScript</span>
                        <span className="px-3 py-1 bg-amber-500/20 text-amber-300 rounded-full text-xs">Node.js</span>
                        <span className="px-3 py-1 bg-cyan-500/20 text-cyan-300 rounded-full text-xs">AWS</span>
                      </div>
                    </div>
                  </div>
                </div>
                {/* Resume Preview */}
                <div className="bg-white rounded-2xl shadow-2xl overflow-hidden">
                  <div className="flex h-full">
                    {/* Sidebar */}
                    <div className="w-1/3 bg-slate-800 p-4 text-white">
                      <img src="https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&crop=face" className="w-16 h-16 rounded-full mx-auto border-2 border-emerald-400 object-cover mb-3" alt="" />
                      <div className="text-center mb-4">
                        <div className="text-sm font-bold">John Anderson</div>
                        <div className="text-xs text-emerald-400">Senior Engineer</div>
                      </div>
                      <div className="text-xs text-slate-400 mb-1">CONTACT</div>
                      <div className="text-[10px] space-y-1 mb-4 text-slate-300">
                        <div>john@email.com</div>
                        <div>+1 234 567 890</div>
                        <div>San Francisco, CA</div>
                      </div>
                      <div className="text-xs text-slate-400 mb-2">SKILLS</div>
                      <div className="space-y-2">
                        <div>
                          <div className="text-[10px] mb-1">JavaScript</div>
                          <div className="h-1.5 bg-slate-600 rounded-full">
                            <div className="h-1.5 bg-emerald-400 rounded-full w-[90%]"></div>
                          </div>
                        </div>
                        <div>
                          <div className="text-[10px] mb-1">React</div>
                          <div className="h-1.5 bg-slate-600 rounded-full">
                            <div className="h-1.5 bg-emerald-400 rounded-full w-[85%]"></div>
                          </div>
                        </div>
                        <div>
                          <div className="text-[10px] mb-1">Node.js</div>
                          <div className="h-1.5 bg-slate-600 rounded-full">
                            <div className="h-1.5 bg-emerald-400 rounded-full w-[80%]"></div>
                          </div>
                        </div>
                      </div>
                    </div>
                    {/* Main Content */}
                    <div className="flex-1 p-4">
                      <div className="border-l-4 border-emerald-500 pl-3 mb-4">
                        <div className="text-lg font-bold text-slate-800">John Anderson</div>
                        <div className="text-sm text-emerald-600">Senior Software Engineer</div>
                      </div>
                      <div className="text-xs text-slate-600 mb-4 leading-relaxed">
                        Passionate software engineer with 8+ years of experience building scalable web applications and leading development teams.
                      </div>
                      <div className="text-sm font-bold text-slate-800 mb-2 flex items-center gap-2">
                        <span className="w-2 h-2 bg-emerald-500 rounded-full"></span>
                        EXPERIENCE
                      </div>
                      <div className="mb-3">
                        <div className="flex justify-between items-start">
                          <div className="text-xs font-semibold text-slate-800">Senior Engineer • Google Inc.</div>
                          <div className="text-[10px] text-slate-400">2020 - Present</div>
                        </div>
                        <div className="text-[10px] text-slate-600 mt-1">• Led development of core platform features</div>
                        <div className="text-[10px] text-slate-600">• Improved system performance by 40%</div>
                      </div>
                      <div>
                        <div className="flex justify-between items-start">
                          <div className="text-xs font-semibold text-slate-800">Software Engineer • Meta</div>
                          <div className="text-[10px] text-slate-400">2018 - 2020</div>
                        </div>
                        <div className="text-[10px] text-slate-600 mt-1">• Built React components library</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section id="features" className="py-20 px-6">
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-4xl md:text-5xl font-bold text-white mb-4">
              Everything You Need
            </h2>
            <p className="text-xl text-slate-400 max-w-2xl mx-auto">
              Powerful features to help you create the perfect resume
            </p>
          </div>
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            {features.map((feature, index) => (
              <div
                key={index}
                className="group p-8 bg-gradient-to-br from-slate-800/50 to-slate-900/50 rounded-2xl border border-white/5 hover:border-emerald-500/30 transition-all hover:-translate-y-1"
              >
                <div className="w-14 h-14 rounded-xl bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center mb-6 group-hover:scale-110 transition-transform">
                  {feature.icon}
                </div>
                <h3 className="text-xl font-semibold text-white mb-3">{feature.title}</h3>
                <p className="text-slate-400">{feature.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Templates Preview */}
      <section id="templates" className="py-20 px-6 bg-gradient-to-b from-transparent to-emerald-950/30">
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-4xl md:text-5xl font-bold text-white mb-4">
              Professional Templates
            </h2>
            <p className="text-xl text-slate-400 max-w-2xl mx-auto">
              Choose from our collection of stunning, ATS-friendly templates
            </p>
          </div>
          <div className="flex overflow-x-auto gap-6 pb-8 snap-x snap-mandatory scrollbar-hide">
            {/* Modern Professional Template */}
            <div className="flex-shrink-0 w-80 snap-center">
              <div className="bg-gradient-to-br from-slate-800 to-slate-900 rounded-2xl border border-white/10 overflow-hidden group hover:border-emerald-500/50 transition-all hover:-translate-y-2 cursor-pointer" onClick={() => navigate('/templates')}>
                <div className="h-96 bg-white relative overflow-hidden">
                  <div className="flex h-full">
                    {/* Sidebar */}
                    <div className="w-28 bg-slate-800 p-3 text-white">
                      <img src="https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&crop=face" className="w-14 h-14 rounded-full mx-auto border-2 border-emerald-400 object-cover mb-2" alt="" />
                      <div className="text-center mb-3">
                        <div className="text-[7px] font-bold">John Anderson</div>
                        <div className="text-[5px] text-emerald-400">Senior Engineer</div>
                      </div>
                      <div className="text-[5px] text-slate-400 mb-1">CONTACT</div>
                      <div className="text-[4px] space-y-0.5 mb-2">
                        <div>john@email.com</div>
                        <div>+1 234 567 890</div>
                        <div>San Francisco, CA</div>
                      </div>
                      <div className="text-[5px] text-slate-400 mb-1">SKILLS</div>
                      <div className="space-y-1">
                        <div><div className="text-[4px]">JavaScript</div><div className="h-1 bg-slate-600 rounded"><div className="h-1 bg-emerald-400 rounded w-[90%]"></div></div></div>
                        <div><div className="text-[4px]">React</div><div className="h-1 bg-slate-600 rounded"><div className="h-1 bg-emerald-400 rounded w-[85%]"></div></div></div>
                        <div><div className="text-[4px]">Node.js</div><div className="h-1 bg-slate-600 rounded"><div className="h-1 bg-emerald-400 rounded w-[80%]"></div></div></div>
                      </div>
                    </div>
                    {/* Main Content */}
                    <div className="flex-1 p-3">
                      <div className="border-l-2 border-emerald-500 pl-2 mb-3">
                        <div className="text-[10px] font-bold text-slate-800">John Anderson</div>
                        <div className="text-[6px] text-emerald-600">Senior Software Engineer</div>
                      </div>
                      <div className="text-[4px] text-slate-600 mb-3 leading-relaxed">Passionate software engineer with 8+ years of experience building scalable web applications.</div>
                      <div className="text-[6px] font-bold text-slate-800 mb-1 flex items-center gap-1"><span className="w-1 h-1 bg-emerald-500 rounded-full"></span>EXPERIENCE</div>
                      <div className="mb-2">
                        <div className="flex justify-between"><div className="text-[5px] font-semibold text-slate-800">Senior Engineer • Google</div><div className="text-[4px] text-slate-400">2020 - Present</div></div>
                        <div className="text-[4px] text-slate-600 mt-0.5">• Led development of core features</div>
                        <div className="text-[4px] text-slate-600">• Improved system performance by 40%</div>
                      </div>
                      <div className="mb-2">
                        <div className="flex justify-between"><div className="text-[5px] font-semibold text-slate-800">Software Engineer • Meta</div><div className="text-[4px] text-slate-400">2018 - 2020</div></div>
                        <div className="text-[4px] text-slate-600 mt-0.5">• Built React components library</div>
                      </div>
                      <div className="text-[6px] font-bold text-slate-800 mb-1 flex items-center gap-1"><span className="w-1 h-1 bg-emerald-500 rounded-full"></span>EDUCATION</div>
                      <div className="text-[5px] font-semibold text-slate-800">MIT</div>
                      <div className="text-[4px] text-slate-600">B.S. Computer Science • 2018</div>
                    </div>
                  </div>
                </div>
                <div className="p-4 flex items-center justify-between">
                  <div>
                    <h3 className="text-lg font-semibold text-white">Modern Professional</h3>
                    <p className="text-sm text-slate-400">Clean two-column layout</p>
                  </div>
                  <span className="text-xs bg-emerald-500/20 text-emerald-300 px-2 py-1 rounded-full">Popular</span>
                </div>
              </div>
            </div>

            {/* Minimalist Elegant Template */}
            <div className="flex-shrink-0 w-80 snap-center">
              <div className="bg-gradient-to-br from-slate-800 to-slate-900 rounded-2xl border border-white/10 overflow-hidden group hover:border-amber-500/50 transition-all hover:-translate-y-2 cursor-pointer" onClick={() => navigate('/templates')}>
                <div className="h-96 bg-white relative overflow-hidden p-4">
                  <div className="text-center border-b border-slate-200 pb-3 mb-3">
                    <img src="https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&h=100&fit=crop&crop=face" className="w-14 h-14 rounded-full mx-auto mb-2 grayscale object-cover" alt="" />
                    <div className="text-[12px] font-light tracking-[0.2em] text-slate-800">SARAH MILLER</div>
                    <div className="text-[7px] tracking-[0.15em] text-slate-500">CREATIVE DIRECTOR</div>
                    <div className="flex justify-center gap-3 mt-2 text-[5px] text-slate-400">
                      <span>sarah@email.com</span>
                      <span>•</span>
                      <span>+1 234 567 890</span>
                      <span>•</span>
                      <span>New York, NY</span>
                    </div>
                  </div>
                  <div className="text-[4px] text-slate-600 italic text-center mb-3">"Award-winning creative director with 10+ years of experience leading design teams at Fortune 500 companies."</div>
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <div className="text-[6px] font-semibold text-slate-800 border-b border-slate-200 pb-0.5 mb-1">Experience</div>
                      <div className="mb-1.5">
                        <div className="text-[5px] font-medium text-slate-800">Creative Director</div>
                        <div className="text-[4px] text-slate-500">Apple Inc. • 2019 - Present</div>
                        <div className="text-[4px] text-slate-600">Led brand redesign reaching 2B users</div>
                      </div>
                      <div>
                        <div className="text-[5px] font-medium text-slate-800">Senior Designer</div>
                        <div className="text-[4px] text-slate-500">Nike • 2015 - 2019</div>
                      </div>
                    </div>
                    <div>
                      <div className="text-[6px] font-semibold text-slate-800 border-b border-slate-200 pb-0.5 mb-1">Education</div>
                      <div className="text-[5px] font-medium text-slate-800">RISD</div>
                      <div className="text-[4px] text-slate-500">MFA Visual Design • 2015</div>
                      <div className="text-[6px] font-semibold text-slate-800 border-b border-slate-200 pb-0.5 mb-1 mt-2">Skills</div>
                      <div className="flex flex-wrap gap-0.5">
                        <span className="text-[4px] bg-slate-100 px-1 py-0.5 rounded">Figma</span>
                        <span className="text-[4px] bg-slate-100 px-1 py-0.5 rounded">Photoshop</span>
                        <span className="text-[4px] bg-slate-100 px-1 py-0.5 rounded">After Effects</span>
                        <span className="text-[4px] bg-slate-100 px-1 py-0.5 rounded">Sketch</span>
                      </div>
                    </div>
                  </div>
                </div>
                <div className="p-4">
                  <h3 className="text-lg font-semibold text-white">Minimalist Elegant</h3>
                  <p className="text-sm text-slate-400">Clean & sophisticated design</p>
                </div>
              </div>
            </div>

            {/* Creative Light Template */}
            <div className="flex-shrink-0 w-80 snap-center">
              <div className="bg-gradient-to-br from-slate-800 to-slate-900 rounded-2xl border border-white/10 overflow-hidden group hover:border-pink-500/50 transition-all hover:-translate-y-2 cursor-pointer" onClick={() => navigate('/templates')}>
                <div className="h-96 bg-[#fefefe] relative overflow-hidden">
                  {/* Decorative Elements */}
                  <div className="absolute top-0 right-0 w-20 h-20 bg-gradient-to-br from-pink-200 to-purple-200 rounded-bl-full opacity-60" />
                  <div className="absolute bottom-0 left-0 w-16 h-16 bg-gradient-to-tr from-blue-200 to-pink-200 rounded-tr-full opacity-50" />
                  
                  {/* Header */}
                  <div className="p-3 relative z-10">
                    <div className="flex items-start gap-2.5">
                      <div className="relative">
                        <div className="absolute -top-0.5 -left-0.5 w-[52px] h-[52px] rounded-xl bg-gradient-to-br from-pink-400 via-purple-400 to-blue-400 rotate-3" />
                        <img src="https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100&h=100&fit=crop&crop=face" className="w-12 h-12 rounded-lg object-cover relative z-10 border-2 border-white" alt="" />
                      </div>
                      <div className="flex-1">
                        <div className="text-[12px] font-extrabold bg-gradient-to-r from-pink-500 via-purple-500 to-blue-500 text-transparent bg-clip-text">Alex Rivera</div>
                        <div className="text-[6px] text-gray-500">Visual Designer & Artist</div>
                        <div className="flex gap-1 mt-1.5 text-[4px]">
                          <span className="px-1.5 py-0.5 bg-pink-50 text-pink-600 rounded-full">✉️ alex@creative.io</span>
                          <span className="px-1.5 py-0.5 bg-purple-50 text-purple-600 rounded-full">📍 Miami</span>
                        </div>
                      </div>
                    </div>
                  </div>
                  
                  {/* Summary */}
                  <div className="px-3 relative z-10">
                    <div className="bg-gradient-to-r from-pink-50 via-purple-50 to-blue-50 rounded-lg p-2 mb-2">
                      <div className="text-[4px] text-gray-600 italic">"Creative designer crafting memorable brand experiences through vibrant visuals."</div>
                    </div>
                  </div>

                  {/* Content */}
                  <div className="px-3 flex gap-2 relative z-10">
                    <div className="w-24">
                      <div className="flex items-center gap-1 mb-1">
                        <div className="w-2 h-0.5 bg-gradient-to-r from-pink-400 to-purple-400 rounded" />
                        <div className="text-[5px] font-bold text-pink-500">SKILLS</div>
                      </div>
                      <div className="flex flex-wrap gap-0.5 mb-2">
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
                            <div className="text-[5px] font-semibold text-gray-800">Lead Designer</div>
                            <div className="text-[4px] text-purple-500">Spotify</div>
                          </div>
                          <span className="text-[3px] text-white bg-gradient-to-r from-pink-400 to-purple-400 px-1 py-0.5 rounded-full">2022-Now</span>
                        </div>
                        <div className="text-gray-500 text-[3px] mt-0.5">Brand & marketing design</div>
                      </div>
                      <div className="relative pl-2">
                        <div className="absolute left-0 top-1 w-1 h-1 rounded-full bg-gradient-to-br from-purple-400 to-blue-400" />
                        <div className="flex justify-between items-start">
                          <div>
                            <div className="text-[5px] font-semibold text-gray-800">Senior Designer</div>
                            <div className="text-[4px] text-blue-500">Instagram</div>
                          </div>
                          <span className="text-[3px] text-gray-400">2019-2022</span>
                        </div>
                      </div>
                      <div className="flex items-center gap-1 mt-2 mb-1">
                        <div className="w-2 h-0.5 bg-gradient-to-r from-purple-400 to-blue-400 rounded" />
                        <div className="text-[5px] font-bold text-purple-500">PROJECTS</div>
                      </div>
                      <div className="flex gap-1">
                        <div className="flex-1 p-1 bg-gradient-to-br from-pink-50 to-purple-50 rounded-lg">
                          <div className="font-semibold text-gray-800 text-[4px]">Brand Kit</div>
                          <div className="text-purple-500 text-[3px]">Figma</div>
                        </div>
                        <div className="flex-1 p-1 bg-gradient-to-br from-purple-50 to-blue-50 rounded-lg">
                          <div className="font-semibold text-gray-800 text-[4px]">Motion</div>
                          <div className="text-blue-500 text-[3px]">AE</div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
                <div className="p-4">
                  <h3 className="text-lg font-semibold text-white">Creative Light</h3>
                  <p className="text-sm text-slate-400">Playful pastel gradients</p>
                </div>
              </div>
            </div>

            {/* Executive Classic Template */}
            <div className="flex-shrink-0 w-80 snap-center">
              <div className="bg-gradient-to-br from-slate-800 to-slate-900 rounded-2xl border border-white/10 overflow-hidden group hover:border-teal-500/50 transition-all hover:-translate-y-2 cursor-pointer" onClick={() => navigate('/templates')}>
                <div className="h-96 bg-white relative overflow-hidden">
                  <div className="bg-teal-700 text-white p-3">
                    <div className="flex items-center gap-3">
                      <img src="https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop&crop=face" className="w-12 h-12 rounded object-cover" alt="" />
                      <div className="flex-1">
                        <div className="text-[11px] font-bold">Michael Chen</div>
                        <div className="text-[6px] text-teal-200">Chief Executive Officer</div>
                        <div className="flex gap-3 mt-1 text-[4px] text-teal-100">
                          <span>✉ michael@exec.com</span>
                          <span>📱 +1 555 0123</span>
                          <span>📍 Boston, MA</span>
                        </div>
                      </div>
                    </div>
                  </div>
                  <div className="p-3">
                    <div className="border-l-2 border-teal-600 pl-2 mb-3">
                      <div className="text-[6px] font-bold text-teal-700">EXECUTIVE SUMMARY</div>
                      <div className="text-[4px] text-slate-600 mt-0.5">Results-driven executive with 15+ years leading Fortune 500 companies through digital transformation. Proven track record of driving $500M+ revenue growth.</div>
                    </div>
                    <div className="border border-slate-200 rounded p-2 mb-2">
                      <div className="text-[6px] font-bold text-teal-700 border-b border-slate-200 pb-0.5 mb-1">PROFESSIONAL EXPERIENCE</div>
                      <div className="mb-1.5">
                        <div className="flex justify-between">
                          <div>
                            <div className="text-[5px] font-bold text-slate-800">Chief Executive Officer</div>
                            <div className="text-[4px] text-teal-600">TechCorp International</div>
                          </div>
                          <div className="text-[4px] text-slate-500">2018 - Present</div>
                        </div>
                        <div className="text-[4px] text-slate-600 mt-0.5">• Increased annual revenue from $200M to $750M</div>
                        <div className="text-[4px] text-slate-600">• Led acquisition of 3 companies valued at $150M</div>
                      </div>
                      <div>
                        <div className="flex justify-between">
                          <div>
                            <div className="text-[5px] font-bold text-slate-800">VP of Operations</div>
                            <div className="text-[4px] text-teal-600">Global Industries</div>
                          </div>
                          <div className="text-[4px] text-slate-500">2012 - 2018</div>
                        </div>
                      </div>
                    </div>
                    <div className="grid grid-cols-2 gap-2">
                      <div className="border border-slate-200 rounded p-1.5">
                        <div className="text-[5px] font-bold text-teal-700 mb-1">EDUCATION</div>
                        <div className="text-[4px] font-medium">Harvard Business School</div>
                        <div className="text-[4px] text-slate-500">MBA, Strategy • 2012</div>
                        <div className="text-[4px] font-medium mt-1">Stanford University</div>
                        <div className="text-[4px] text-slate-500">BS Engineering • 2008</div>
                      </div>
                      <div className="border border-slate-200 rounded p-1.5">
                        <div className="text-[5px] font-bold text-teal-700 mb-1">EXPERTISE</div>
                        <div className="text-[4px] text-slate-600">• Strategic Leadership</div>
                        <div className="text-[4px] text-slate-600">• M&A Integration</div>
                        <div className="text-[4px] text-slate-600">• Digital Transformation</div>
                        <div className="text-[4px] text-slate-600">• P&L Management</div>
                      </div>
                    </div>
                  </div>
                </div>
                <div className="p-4">
                  <h3 className="text-lg font-semibold text-white">Executive Classic</h3>
                  <p className="text-sm text-slate-400">Traditional & professional</p>
                </div>
              </div>
            </div>

            {/* Tech Developer Template */}
            <div className="flex-shrink-0 w-80 snap-center">
              <div className="bg-gradient-to-br from-slate-800 to-slate-900 rounded-2xl border border-white/10 overflow-hidden group hover:border-cyan-500/50 transition-all hover:-translate-y-2 cursor-pointer" onClick={() => navigate('/templates')}>
                <div className="h-96 bg-slate-900 relative overflow-hidden">
                  <div className="flex h-full">
                    <div className="w-24 bg-slate-800 p-2 border-r border-slate-700">
                      <img src="https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=100&h=100&fit=crop&crop=face" className="w-12 h-12 rounded mx-auto border-2 border-cyan-400 object-cover mb-2" alt="" />
                      <div className="text-center text-[6px] font-bold text-white mb-0.5">David_Kim</div>
                      <div className="text-center text-[4px] text-cyan-400 mb-2">Full Stack Dev</div>
                      <div className="text-[5px] text-cyan-400 mb-1 font-mono">&lt;contact/&gt;</div>
                      <div className="text-[4px] text-slate-400 space-y-0.5 mb-2">
                        <div>david@dev.io</div>
                        <div>github/davidkim</div>
                        <div>Seattle, WA</div>
                      </div>
                      <div className="text-[5px] text-cyan-400 mb-1 font-mono">&lt;skills/&gt;</div>
                      <div className="flex flex-wrap gap-0.5">
                        <span className="text-[4px] bg-cyan-900/50 text-cyan-300 px-1 py-0.5 rounded border border-cyan-700/50">TS</span>
                        <span className="text-[4px] bg-cyan-900/50 text-cyan-300 px-1 py-0.5 rounded border border-cyan-700/50">React</span>
                        <span className="text-[4px] bg-cyan-900/50 text-cyan-300 px-1 py-0.5 rounded border border-cyan-700/50">Node</span>
                        <span className="text-[4px] bg-cyan-900/50 text-cyan-300 px-1 py-0.5 rounded border border-cyan-700/50">AWS</span>
                        <span className="text-[4px] bg-cyan-900/50 text-cyan-300 px-1 py-0.5 rounded border border-cyan-700/50">Go</span>
                        <span className="text-[4px] bg-cyan-900/50 text-cyan-300 px-1 py-0.5 rounded border border-cyan-700/50">K8s</span>
                      </div>
                    </div>
                    <div className="flex-1 p-2">
                      <div className="border-l-2 border-cyan-400 pl-2 mb-3">
                        <div className="text-[10px] font-bold text-white font-mono">David_Kim</div>
                        <div className="text-[6px] text-cyan-400 font-mono">// Full Stack Developer</div>
                      </div>
                      <div className="text-[4px] text-slate-400 mb-2 bg-slate-800 p-1 rounded border border-slate-700 font-mono">
                        <span className="text-cyan-400">const</span> summary = <span className="text-green-400">"Building scalable apps with 6+ years experience"</span>;
                      </div>
                      <div className="text-[5px] text-cyan-400 font-mono mb-1">&lt;experience&gt;</div>
                      <div className="bg-slate-800 rounded p-1.5 mb-1.5 border border-slate-700">
                        <div className="flex justify-between">
                          <div className="text-[5px] font-bold text-white">Senior Developer</div>
                          <div className="text-[4px] text-cyan-400 font-mono">2021-now</div>
                        </div>
                        <div className="text-[4px] text-slate-400">@ Amazon</div>
                        <div className="text-[4px] text-slate-500 mt-0.5">• Built microservices handling 1M+ req/day</div>
                      </div>
                      <div className="bg-slate-800 rounded p-1.5 border border-slate-700">
                        <div className="flex justify-between">
                          <div className="text-[5px] font-bold text-white">Developer</div>
                          <div className="text-[4px] text-cyan-400 font-mono">2018-2021</div>
                        </div>
                        <div className="text-[4px] text-slate-400">@ Netflix</div>
                      </div>
                      <div className="text-[5px] text-cyan-400 font-mono mt-2 mb-1">&lt;projects&gt;</div>
                      <div className="grid grid-cols-2 gap-1">
                        <div className="bg-slate-800 rounded p-1 border border-slate-700">
                          <div className="text-[4px] font-bold text-white">CloudAPI</div>
                          <div className="text-[3px] text-cyan-400">⭐ 2.3k</div>
                        </div>
                        <div className="bg-slate-800 rounded p-1 border border-slate-700">
                          <div className="text-[4px] font-bold text-white">DevCLI</div>
                          <div className="text-[3px] text-cyan-400">⭐ 1.1k</div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
                <div className="p-4">
                  <h3 className="text-lg font-semibold text-white">Tech Developer</h3>
                  <p className="text-sm text-slate-400">Code-inspired dark theme</p>
                </div>
              </div>
            </div>
          </div>
          <div className="text-center mt-8">
            <button
              onClick={() => navigate('/templates')}
              className="px-8 py-4 bg-gradient-to-r from-emerald-500 to-teal-600 text-white rounded-full font-semibold hover:shadow-xl hover:shadow-emerald-500/30 transition-all hover:-translate-y-1"
            >
              Browse All Templates
            </button>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-20 px-6">
        <div className="max-w-4xl mx-auto">
          <div className="relative overflow-hidden bg-gradient-to-r from-emerald-600 to-teal-600 rounded-3xl p-12 text-center">
            <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHZpZXdCb3g9IjAgMCA2MCA2MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48ZyBmaWxsPSJub25lIiBmaWxsLXJ1bGU9ImV2ZW5vZGQiPjxnIGZpbGw9IiNmZmYiIGZpbGwtb3BhY2l0eT0iMC4xIj48cGF0aCBkPSJNMzYgMzRoLTJ2LTRoMnYyaDR2LTJoMnY0aC0ydjJoLTR2LTJ6bTAtMzBoLTJ2NGgyVjJ6TTAgMzZoNHYtMkgydi00SDB2NnptMC0xMmg0di0ySDB2MnptMTIgMTJoNHYtMmgtMnYtNGgtMnY2em0wLTEyaDR2LTJoLTR2MnptMTIgMTJoNHYtMmgtMnYtNGgtMnY2em0wLTEyaDR2LTJoLTR2MnoiLz48L2c+PC9nPjwvc3ZnPg==')] opacity-20" />
            <h2 className="text-4xl md:text-5xl font-bold text-white mb-4 relative">
              Ready to Build Your Resume?
            </h2>
            <p className="text-xl text-white/80 mb-8 relative">
              Join thousands of professionals who have landed their dream jobs.
            </p>
            <button
              onClick={() => navigate('/templates')}
              className="relative px-10 py-4 bg-white text-emerald-600 rounded-full font-semibold text-lg hover:shadow-xl transition-all hover:-translate-y-1"
            >
              Get Started Free
            </button>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-white/5 py-12 px-6">
        <div className="max-w-7xl mx-auto flex flex-col md:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center">
              <FileText className="w-4 h-4 text-white" />
            </div>
            <span className="text-lg font-bold text-white">ResumeForge</span>
          </div>
          <p className="text-slate-400 text-sm">
            © 2024 ResumeForge. All rights reserved.
          </p>
        </div>
      </footer>
    </div>
  );
}

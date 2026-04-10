import { useNavigate } from 'react-router-dom';
import {
  ArrowLeft,
  Check,
  FileText,
  Star,
  Briefcase,
  Code,
  GraduationCap,
  Palette,
  Sparkles,
} from 'lucide-react';
import { templates } from '../data/templates';
import { useResume } from '../context/ResumeContext';
import type { Template, TemplateCategory } from '../types/resume';
import { TemplateThumbnail } from '../components/TemplateThumbnail';

const categoryIcon: Record<TemplateCategory, typeof Briefcase> = {
  corporate: Briefcase,
  creative: Palette,
  tech: Code,
  academic: GraduationCap,
  minimal: Sparkles,
};

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

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-950 via-slate-900 to-emerald-950">
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

      <main className="max-w-7xl mx-auto px-6 py-12">
        <div className="text-center mb-12">
          <h1 className="text-4xl md:text-5xl font-bold text-white mb-4">Choose Your Template</h1>
          <p className="text-xl text-slate-400">Select a professionally designed template that matches your style</p>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
          {templates.map((template) => {
            const Icon = categoryIcon[template.category];
            return (
              <div
                key={template.id}
                onClick={() => handleSelectTemplate(template)}
                className={`group cursor-pointer transition-all duration-300 ${
                  selectedTemplate?.id === template.id ? 'scale-[1.02]' : 'hover:scale-[1.02]'
                }`}
              >
                <div
                  className={`relative bg-gradient-to-br from-slate-800/50 to-slate-900/50 rounded-2xl border-2 overflow-hidden transition-all ${
                    selectedTemplate?.id === template.id
                      ? 'border-emerald-500 shadow-xl shadow-emerald-500/20'
                      : 'border-white/5 hover:border-white/20'
                  }`}
                >
                  {selectedTemplate?.id === template.id && (
                    <div className="absolute top-4 right-4 z-10 w-8 h-8 bg-emerald-500 rounded-full flex items-center justify-center shadow-lg">
                      <Check className="w-5 h-5 text-white" />
                    </div>
                  )}

                  {template.id === 'modern' && (
                    <div className="absolute top-4 left-4 z-10 flex items-center gap-1 px-3 py-1 bg-gradient-to-r from-amber-500 to-orange-500 rounded-full text-xs font-semibold text-white">
                      <Star className="w-3 h-3 fill-current" />
                      Popular
                    </div>
                  )}

                  <div className="h-64 overflow-hidden rounded-t-xl m-1 relative z-0">
                    <TemplateThumbnail template={template} />
                  </div>

                  <div className="p-5 bg-slate-900/50">
                    <div className="flex items-center gap-2 mb-2">
                      <div
                        className="w-8 h-8 rounded-lg flex items-center justify-center text-white"
                        style={{ backgroundColor: template.colors.primary }}
                      >
                        <Icon className="w-4 h-4" />
                      </div>
                      <h3 className="text-lg font-semibold text-white">{template.name}</h3>
                    </div>
                    <p className="text-slate-400 text-sm mb-3">{template.description}</p>

                    <div className="flex items-center gap-2 text-xs">
                      <span className="text-slate-500">Best for:</span>
                      <span className="text-slate-300">{template.bestFor}</span>
                    </div>

                    <div className="flex items-center gap-2 mt-3 pt-3 border-t border-white/5">
                      <span className="text-xs text-slate-500">Theme:</span>
                      <div className="flex gap-1.5">
                        <div className="w-5 h-5 rounded-full ring-2 ring-white/10" style={{ backgroundColor: template.colors.primary }} />
                        <div className="w-5 h-5 rounded-full ring-2 ring-white/10" style={{ backgroundColor: template.colors.secondary }} />
                        <div className="w-5 h-5 rounded-full ring-2 ring-white/10" style={{ backgroundColor: template.colors.accent }} />
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            );
          })}
        </div>

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

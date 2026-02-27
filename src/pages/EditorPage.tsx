import { useRef, useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, Download, FileText, Loader2, ZoomIn, ZoomOut, Eye, Palette } from 'lucide-react';
import html2canvas from 'html2canvas';
import jsPDF from 'jspdf';
import { useResume } from '../context/ResumeContext';
import { EditorForm } from '../components/EditorForm';
import { ResumePreview } from '../components/ResumePreview';
import { templates } from '../data/templates';

export function EditorPage() {
  const navigate = useNavigate();
  const { selectedTemplate, setSelectedTemplate } = useResume();
  const resumeRef = useRef<HTMLDivElement>(null);
  const printRef = useRef<HTMLDivElement>(null);
  const [isExporting, setIsExporting] = useState(false);
  const [zoom, setZoom] = useState(0.5);
  const [showTemplateSelector, setShowTemplateSelector] = useState(false);

  useEffect(() => {
    if (!selectedTemplate) {
      navigate('/templates');
    }
  }, [selectedTemplate, navigate]);

  const handleExportPDF = async () => {
    if (!printRef.current) return;

    setIsExporting(true);
    try {
      const element = printRef.current;
      
      // Wait for fonts to be ready
      await document.fonts.ready;
      
      // Wait for any images to load
      const images = element.querySelectorAll('img');
      await Promise.all(
        Array.from(images).map((img) => {
          if (img.complete) return Promise.resolve();
          return new Promise((resolve) => {
            img.onload = resolve;
            img.onerror = resolve;
          });
        })
      );

      // Small delay to ensure everything is rendered
      await new Promise(resolve => setTimeout(resolve, 100));
      
      // Render the element to canvas with exact dimensions
      const canvas = await html2canvas(element, {
        scale: 2,
        useCORS: true,
        allowTaint: true,
        logging: false,
        width: 794,
        height: 1123,
        windowWidth: 794,
        windowHeight: 1123,
        onclone: (clonedDoc, clonedElement) => {
          // Ensure the cloned element has the exact styles
          clonedElement.style.width = '794px';
          clonedElement.style.height = '1123px';
          clonedElement.style.overflow = 'hidden';
          clonedElement.style.transform = 'none';
          
          // Force font rendering
          clonedDoc.body.style.fontFamily = "'Inter', 'Playfair Display', 'Source Code Pro', Georgia, sans-serif";
        }
      });

      // Create PDF with exact A4 dimensions
      const pdf = new jsPDF({
        orientation: 'portrait',
        unit: 'mm',
        format: 'a4',
        compress: true
      });

      // A4 in mm: 210 x 297
      const pdfWidth = 210;
      const pdfHeight = 297;
      
      // Convert canvas to image
      const imgData = canvas.toDataURL('image/png', 1.0);

      // Add image to fill the entire page
      pdf.addImage(imgData, 'PNG', 0, 0, pdfWidth, pdfHeight, undefined, 'FAST');
      
      pdf.save('resume.pdf');
    } catch (error) {
      console.error('Error generating PDF:', error);
      alert('Error generating PDF. Please try again.');
    } finally {
      setIsExporting(false);
    }
  };

  const handleZoomIn = () => {
    setZoom((prev) => Math.min(prev + 0.1, 1));
  };

  const handleZoomOut = () => {
    setZoom((prev) => Math.max(prev - 0.1, 0.3));
  };

  if (!selectedTemplate) {
    return null;
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-950 via-slate-900 to-emerald-950">
      {/* Header */}
      <header className="sticky top-0 z-50 bg-slate-950/80 backdrop-blur-xl border-b border-white/5">
        <div className="max-w-full mx-auto px-6 py-3 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <button
              onClick={() => navigate('/templates')}
              className="flex items-center gap-2 text-slate-400 hover:text-white transition-colors"
            >
              <ArrowLeft className="w-5 h-5" />
              <span className="hidden sm:inline">Templates</span>
            </button>
            <div className="h-6 w-px bg-slate-700" />
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center">
                <FileText className="w-4 h-4 text-white" />
              </div>
              <span className="text-lg font-bold text-white hidden sm:inline">ResumeForge</span>
            </div>
          </div>

          <div className="flex items-center gap-2">
            {/* Template Selector */}
            <div className="relative">
              <button
                onClick={() => setShowTemplateSelector(!showTemplateSelector)}
                className="flex items-center gap-2 px-4 py-2 bg-slate-800 text-slate-300 rounded-xl hover:bg-slate-700 transition-colors"
              >
                <Palette className="w-4 h-4" />
                <span className="hidden sm:inline">{selectedTemplate.name}</span>
              </button>
              {showTemplateSelector && (
                <div className="absolute top-full right-0 mt-2 w-64 bg-slate-800 rounded-xl shadow-xl border border-slate-700 p-2 z-50">
                  <p className="text-xs text-slate-400 px-3 py-2">Switch Template</p>
                  {templates.map((template) => (
                    <button
                      key={template.id}
                      onClick={() => {
                        setSelectedTemplate(template);
                        setShowTemplateSelector(false);
                      }}
                      className={`w-full flex items-center gap-3 px-3 py-2 rounded-lg transition-colors ${
                        selectedTemplate.id === template.id
                          ? 'bg-emerald-500/20 text-emerald-300'
                          : 'hover:bg-slate-700 text-slate-300'
                      }`}
                    >
                      <div
                        className="w-4 h-4 rounded"
                        style={{ backgroundColor: template.colors.primary }}
                      />
                      <span className="text-sm">{template.name}</span>
                    </button>
                  ))}
                </div>
              )}
            </div>

            {/* Zoom Controls */}
            <div className="hidden md:flex items-center gap-1 px-2 py-1 bg-slate-800 rounded-xl">
              <button
                onClick={handleZoomOut}
                className="p-2 text-slate-400 hover:text-white transition-colors"
              >
                <ZoomOut className="w-4 h-4" />
              </button>
              <span className="text-sm text-slate-400 w-12 text-center">
                {Math.round(zoom * 100)}%
              </span>
              <button
                onClick={handleZoomIn}
                className="p-2 text-slate-400 hover:text-white transition-colors"
              >
                <ZoomIn className="w-4 h-4" />
              </button>
            </div>

            {/* Export Button */}
            <button
              onClick={handleExportPDF}
              disabled={isExporting}
              className="flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-emerald-500 to-teal-600 text-white rounded-xl font-medium hover:shadow-lg hover:shadow-emerald-500/25 transition-all hover:-translate-y-0.5 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:translate-y-0"
            >
              {isExporting ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  <span className="hidden sm:inline">Exporting...</span>
                </>
              ) : (
                <>
                  <Download className="w-4 h-4" />
                  <span className="hidden sm:inline">Export PDF</span>
                </>
              )}
            </button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <div className="flex h-[calc(100vh-65px)]">
        {/* Left Panel - Form */}
        <div className="w-full lg:w-[480px] xl:w-[520px] overflow-y-auto border-r border-white/5 bg-slate-900/30">
          <div className="p-6">
            <div className="mb-6">
              <h2 className="text-2xl font-bold text-white mb-2">Build Your Resume</h2>
              <p className="text-slate-400">Fill in your information below. Changes appear instantly in the preview.</p>
            </div>
            <EditorForm />
          </div>
        </div>

        {/* Right Panel - Preview */}
        <div className="hidden lg:flex flex-1 flex-col bg-slate-800/20">
          {/* Preview Header */}
          <div className="flex items-center justify-between px-6 py-3 border-b border-white/5">
            <div className="flex items-center gap-2 text-slate-400">
              <Eye className="w-4 h-4" />
              <span className="text-sm">Live Preview</span>
            </div>
            <span className="text-xs text-slate-500">A4 Format (210 × 297 mm)</span>
          </div>

          {/* Preview Container */}
          <div className="flex-1 overflow-auto p-8 bg-slate-700/30">
            <div className="flex justify-center">
              <div
                style={{
                  transform: `scale(${zoom})`,
                  transformOrigin: 'top center',
                }}
                className="transition-transform duration-200"
              >
                <div className="shadow-2xl shadow-black/50 rounded-sm overflow-hidden">
                  <ResumePreview ref={resumeRef} />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Mobile Preview Toggle */}
      <div className="lg:hidden fixed bottom-6 right-6">
        <button
          onClick={() => {
            const previewModal = document.getElementById('preview-modal');
            if (previewModal) {
              previewModal.classList.toggle('hidden');
            }
          }}
          className="w-14 h-14 bg-gradient-to-r from-emerald-500 to-teal-600 text-white rounded-full shadow-lg flex items-center justify-center"
        >
          <Eye className="w-6 h-6" />
        </button>
      </div>

      {/* Mobile Preview Modal */}
      <div
        id="preview-modal"
        className="hidden lg:hidden fixed inset-0 z-50 bg-slate-950/95 overflow-auto"
      >
        <div className="sticky top-0 z-10 flex items-center justify-between px-4 py-3 bg-slate-900 border-b border-white/5">
          <span className="text-white font-medium">Preview</span>
          <button
            onClick={() => {
              const previewModal = document.getElementById('preview-modal');
              if (previewModal) {
                previewModal.classList.add('hidden');
              }
            }}
            className="text-slate-400 hover:text-white"
          >
            Close
          </button>
        </div>
        <div className="p-4 flex justify-center">
          <div style={{ transform: 'scale(0.4)', transformOrigin: 'top center' }}>
            <ResumePreview ref={resumeRef} />
          </div>
        </div>
      </div>

      {/* Hidden container for PDF export - positioned off-screen without transforms */}
      <div 
        style={{ 
          position: 'absolute', 
          left: '-10000px', 
          top: 0,
        }}
        aria-hidden="true"
      >
        <ResumePreview ref={printRef} />
      </div>
    </div>
  );
}

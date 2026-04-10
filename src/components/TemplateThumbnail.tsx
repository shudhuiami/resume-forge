import { ResumeProvider } from '../context/ResumeContext';
import { sampleResume } from '../data/sampleResume';
import type { Template } from '../types/resume';
import { A4_HEIGHT_PX, A4_WIDTH_PX } from '../constants/layout';
import { ResumePreview } from './ResumePreview';

const THUMB_HEIGHT = 256;

export function TemplateThumbnail({ template }: { template: Template }) {
  const scale = THUMB_HEIGHT / A4_HEIGHT_PX;
  return (
    <ResumeProvider initialResumeData={sampleResume} initialTemplate={template}>
      <div className="h-64 overflow-hidden flex justify-center bg-slate-800/40 rounded-t-xl">
        <div
          style={{
            width: A4_WIDTH_PX * scale,
            height: THUMB_HEIGHT,
          }}
        >
          <div
            style={{
              width: A4_WIDTH_PX,
              height: A4_HEIGHT_PX,
              transform: `scale(${scale})`,
              transformOrigin: 'top center',
            }}
          >
            <ResumePreview />
          </div>
        </div>
      </div>
    </ResumeProvider>
  );
}

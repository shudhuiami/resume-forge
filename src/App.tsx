import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { ResumeProvider } from './context/ResumeContext';
import { LandingPage } from './pages/LandingPage';
import { TemplatesPage } from './pages/TemplatesPage';
import { EditorPage } from './pages/EditorPage';
import { PrintPage } from './pages/PrintPage';

export function App() {
  return (
    <ResumeProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<LandingPage />} />
          <Route path="/templates" element={<TemplatesPage />} />
          <Route path="/print" element={<PrintPage />} />
          <Route path="/editor" element={<EditorPage />} />
        </Routes>
      </BrowserRouter>
    </ResumeProvider>
  );
}

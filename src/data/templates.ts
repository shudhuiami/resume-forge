import { Template } from '../types/resume';

export const templates: Template[] = [
  {
    id: 'modern',
    name: 'Modern Professional',
    description: 'Two-column layout with sidebar. Clean and organized with skill bars and clear sections.',
    preview: 'modern',
    colors: {
      primary: '#3b82f6',
      secondary: '#1e293b',
      accent: '#f1f5f9',
    },
  },
  {
    id: 'minimal',
    name: 'Minimalist Elegant',
    description: 'Clean white design with elegant typography. Focuses on content with refined aesthetics.',
    preview: 'minimal',
    colors: {
      primary: '#374151',
      secondary: '#9ca3af',
      accent: '#ffffff',
    },
  },
  {
    id: 'creative',
    name: 'Creative Light',
    description: 'Playful pastel gradients with modern aesthetic. Perfect for creative professionals who want to stand out.',
    preview: 'creative',
    colors: {
      primary: '#ec4899',
      secondary: '#8b5cf6',
      accent: '#fdf2f8',
    },
  },
  {
    id: 'executive',
    name: 'Executive Classic',
    description: 'Traditional professional design with teal accents. Ideal for senior roles.',
    preview: 'executive',
    colors: {
      primary: '#0f766e',
      secondary: '#134e4a',
      accent: '#f0fdfa',
    },
  },
  {
    id: 'tech',
    name: 'Tech Developer',
    description: 'Dark theme with cyan accents and code-inspired styling. Built for tech professionals.',
    preview: 'tech',
    colors: {
      primary: '#06b6d4',
      secondary: '#0f172a',
      accent: '#1e293b',
    },
  },
];

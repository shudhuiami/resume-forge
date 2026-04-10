import type { ComponentType } from 'react';
import type { Template, TemplateCategory } from '../types/resume';
import { ModernTemplate } from './modern/ModernTemplate';
import { MinimalTemplate } from './minimal/MinimalTemplate';
import { CreativeTemplate } from './creative/CreativeTemplate';
import { ExecutiveTemplate } from './executive/ExecutiveTemplate';
import { TechTemplate } from './tech/TechTemplate';
import {
  AtlasTemplate,
  HorizonTemplate,
  MonoTemplate,
  SlateTemplate,
  IvoryTemplate,
} from './additional/SetA';
import {
  CrimsonTemplate,
  OceanTemplate,
  ForestTemplate,
  SunsetTemplate,
  NoirTemplate,
} from './additional/SetB';
import {
  PaperTemplate,
  GridTemplate,
  StripeTemplate,
  PulseTemplate,
  SummitTemplate,
} from './additional/SetC';

export type ResumeTemplateComponent = ComponentType<Record<string, never>>;

const meta = (
  id: string,
  name: string,
  description: string,
  category: TemplateCategory,
  bestFor: string,
  colors: Template['colors'],
  preview = id,
  tags?: string[]
): Template => ({
  id,
  name,
  description,
  preview,
  colors,
  category,
  bestFor,
  tags,
});

export const templates: Template[] = [
  meta('modern', 'Modern Professional', 'Two-column layout with sidebar. Skill bars and clear sections.', 'corporate', 'Business, Marketing, Finance', {
    primary: '#3b82f6',
    secondary: '#1e293b',
    accent: '#f1f5f9',
  }),
  meta('minimal', 'Minimalist Elegant', 'Refined typography and whitespace. Content-first.', 'minimal', 'Design, Writing, Academia', {
    primary: '#374151',
    secondary: '#9ca3af',
    accent: '#ffffff',
  }),
  meta('creative', 'Creative Light', 'Pastel gradients and playful accents.', 'creative', 'Art, Design, Media', {
    primary: '#ec4899',
    secondary: '#8b5cf6',
    accent: '#fdf2f8',
  }),
  meta('executive', 'Executive Classic', 'Traditional layout with strong hierarchy.', 'corporate', 'Management, Consulting, Law', {
    primary: '#0f766e',
    secondary: '#134e4a',
    accent: '#f0fdfa',
  }),
  meta('tech', 'Tech Developer', 'Dark theme with monospace accents.', 'tech', 'Software, IT, Engineering', {
    primary: '#06b6d4',
    secondary: '#0f172a',
    accent: '#1e293b',
  }),
  meta('atlas', 'Atlas Coral', 'Navy & coral duo-tone, hero photo, pastel skill pills & project cards.', 'corporate', 'Operations, Product, General', {
    primary: '#fb7185',
    secondary: '#0c1929',
    accent: '#f8fafc',
  }),
  meta('horizon', 'Horizon Sky', 'Aqua & indigo timeline, portrait, soft skill chips.', 'corporate', 'Consulting, PM, Career changers', {
    primary: '#0ea5e9',
    secondary: '#4f46e5',
    accent: '#ecfeff',
  }),
  meta('mono', 'Mono Matrix', 'Cyberpunk terminal: photo card, neon green & pink on charcoal.', 'tech', 'Engineering, DevOps, Security', {
    primary: '#4ade80',
    secondary: '#0c0c0f',
    accent: '#f472b6',
  }),
  meta('slate', 'Slate Amethyst', 'Deep purple gradient sidebar, gold ring photo, cream content.', 'corporate', 'Analytics, Finance, Ops', {
    primary: '#7c3aed',
    secondary: '#312e81',
    accent: '#faf5ff',
  }),
  meta('ivory', 'Ivory Heritage', 'Cream paper, double gold ring photo, serif elegance.', 'academic', 'Research, Education, Humanities', {
    primary: '#b45309',
    secondary: '#7f1d1d',
    accent: '#fffbeb',
  }),
  meta('crimson', 'Crimson Bold', 'Red spine, portrait, date pills & blush summary card.', 'corporate', 'Sales, Leadership, Legal', {
    primary: '#dc2626',
    secondary: '#450a0a',
    accent: '#fffafa',
  }),
  meta('ocean', 'Ocean Teal', 'Teal & cyan waves, circular photo, glassy experience cards.', 'creative', 'Marketing, UX, Customer success', {
    primary: '#0d9488',
    secondary: '#134e4a',
    accent: '#ccfbf1',
  }),
  meta('forest', 'Forest Canopy', 'Gradient green banner, framed photo, lime skill chips.', 'corporate', 'Sustainability, Healthcare, Nonprofit', {
    primary: '#15803d',
    secondary: '#365314',
    accent: '#f7fee7',
  }),
  meta('sunset', 'Sunset Aurora', 'Orange–magenta gradient header, portrait overlap, warm body.', 'creative', 'Content, Social, Brand', {
    primary: '#fb923c',
    secondary: '#a855f7',
    accent: '#fff7ed',
  }),
  meta('noir', 'Noir Gold', 'Dark cinema: gold-framed photo, champagne type, gold rules.', 'minimal', 'Film, Photography, Luxury', {
    primary: '#d4af37',
    secondary: '#0c0a09',
    accent: '#fafaf9',
  }),
  meta('paper', 'Paper Chronicle', 'Editorial cream, ink & rust accents, portrait masthead.', 'academic', 'Journalism, Editorial, Policy', {
    primary: '#1e3a8a',
    secondary: '#b45309',
    accent: '#fffef7',
  }),
  meta('grid', 'Grid Mosaic', 'Dot grid + colorful bento cards, photo tile, mixed panels.', 'tech', 'Architecture, Product design, UX', {
    primary: '#6366f1',
    secondary: '#18181b',
    accent: '#fafafa',
  }),
  meta('stripe', 'Stripe Prism', 'Rainbow spine, violet portrait, floating white cards.', 'creative', 'Startups, Portfolio, Product', {
    primary: '#7c3aed',
    secondary: '#312e81',
    accent: '#faf5ff',
  }),
  meta('pulse', 'Pulse Ring', 'Gradient ring avatar (photo or initials), lavender orbit layout.', 'creative', 'Community, Events, People roles', {
    primary: '#a855f7',
    secondary: '#6366f1',
    accent: '#fdf4ff',
  }),
  meta('summit', 'Summit Peak', 'Blue-slate hero with floating card, photo on peak, skill chips.', 'corporate', 'Strategy, Executive summaries', {
    primary: '#0ea5e9',
    secondary: '#0f172a',
    accent: '#f1f5f9',
  }),
];

export const templateComponents: Record<string, ResumeTemplateComponent> = {
  modern: ModernTemplate,
  minimal: MinimalTemplate,
  creative: CreativeTemplate,
  executive: ExecutiveTemplate,
  tech: TechTemplate,
  atlas: AtlasTemplate,
  horizon: HorizonTemplate,
  mono: MonoTemplate,
  slate: SlateTemplate,
  ivory: IvoryTemplate,
  crimson: CrimsonTemplate,
  ocean: OceanTemplate,
  forest: ForestTemplate,
  sunset: SunsetTemplate,
  noir: NoirTemplate,
  paper: PaperTemplate,
  grid: GridTemplate,
  stripe: StripeTemplate,
  pulse: PulseTemplate,
  summit: SummitTemplate,
};

export function getTemplateComponent(id: string | undefined): ResumeTemplateComponent {
  if (!id) return ModernTemplate;
  return templateComponents[id] ?? ModernTemplate;
}

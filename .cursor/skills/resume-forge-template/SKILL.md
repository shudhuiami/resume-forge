---
name: resume-forge-template
description: Add or modify a ResumeForge resume template (registry, component, gallery, PDF parity).
---

# Add a ResumeForge template

## 1. Pick an id

- Use **kebab-case**, stable string (e.g. `aurora`, `ledger`). It appears in URLs and `templateComponents`.

## 2. Metadata

In [src/templates/registry.ts](src/templates/registry.ts):

- Append a `meta(...)` entry to the `templates` array with `id`, `name`, `description`, `category`, `bestFor`, and `colors`.
- Append `yourId: YourTemplateComponent` to `templateComponents`.

## 3. Component

- Add `YourTemplate.tsx` under `src/templates/<id>/` or a shared file under `src/templates/additional/` if it is a small variant batch.
- Call `useResume()` from [ResumeContext](src/context/ResumeContext.tsx).
- Root box: **794×1123** px (import `A4_WIDTH_PX` / `A4_HEIGHT_PX` from [layout constants](src/constants/layout.ts) when sizing).
- Use inline styles or existing patterns; match font stacks in [fonts.ts](src/templates/fonts.ts) where relevant.

## 4. Verify

- Gallery: [TemplatesPage](src/pages/TemplatesPage.tsx) picks up the registry automatically; thumbnail uses [TemplateThumbnail](src/components/TemplateThumbnail.tsx) + [sampleResume](src/data/sampleResume.ts).
- Editor: select the template and confirm live preview matches PDF export (same DOM path via off-screen `printRef`).
- Run `npm run build` and `npm run test:e2e` (Playwright lists every template name on `/templates`).

## 5. PR checklist

- [ ] `templates` array + `templateComponents` updated
- [ ] No duplicate fake mini-previews in the gallery
- [ ] Export still targets fixed A4 dimensions if you changed layout constants

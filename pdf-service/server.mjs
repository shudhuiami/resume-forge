import cors from 'cors';
import express from 'express';
import { chromium } from 'playwright';

const PORT = Number(process.env.PDF_SERVICE_PORT || 3040);
const A4_W = 794;
const A4_H = 1123;
const STORAGE_KEY = 'resume-forge-pdf-export';

const app = express();
app.use(cors({ origin: true, credentials: true }));
app.use(express.json({ limit: '25mb' }));

app.get('/health', (_, res) => {
  res.json({ ok: true });
});

app.post('/pdf', async (req, res) => {
  const { printUrl, snapshot } = req.body ?? {};
  if (!printUrl || typeof printUrl !== 'string') {
    return res.status(400).json({ error: 'printUrl (string) is required' });
  }
  if (!snapshot?.resumeData || !snapshot?.selectedTemplate?.id) {
    return res.status(400).json({ error: 'snapshot.resumeData and snapshot.selectedTemplate.id are required' });
  }

  let browser;
  try {
    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage({
      viewport: { width: A4_W, height: A4_H },
      deviceScaleFactor: 1,
    });

    await page.addInitScript(
      ({ key, data }) => {
        sessionStorage.setItem(key, JSON.stringify(data));
      },
      {
        key: STORAGE_KEY,
        data: {
          resumeData: snapshot.resumeData,
          selectedTemplate: snapshot.selectedTemplate,
        },
      },
    );

    await page.goto(printUrl, { waitUntil: 'load', timeout: 120000 });
    await page.waitForSelector('[data-print-ready="true"]', { timeout: 90000 });

    const pdfBuffer = await page.pdf({
      width: `${A4_W}px`,
      height: `${A4_H}px`,
      printBackground: true,
      margin: { top: '0', right: '0', bottom: '0', left: '0' },
    });

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', 'attachment; filename="resume.pdf"');
    res.send(Buffer.from(pdfBuffer));
  } catch (err) {
    console.error('[pdf-service]', err);
    const message = err instanceof Error ? err.message : String(err);
    res.status(500).json({ error: message });
  } finally {
    if (browser) {
      await browser.close();
    }
  }
});

app.listen(PORT, () => {
  console.log(`ResumeForge PDF service listening on http://localhost:${PORT}`);
  console.log('POST /pdf with JSON { printUrl, snapshot }');
  console.log('If Chromium is missing, run: npx playwright install chromium');
});

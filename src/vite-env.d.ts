/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_PDF_SERVICE_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

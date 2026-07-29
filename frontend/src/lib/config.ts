// `import.meta.env` sólo lo inyecta Vite. El encadenamiento opcional permite
// importar este módulo (y los que dependen de él) desde los tests con tsx.
export const API_BASE_URL =
  (import.meta as any).env?.VITE_API_BASE_URL || 'https://dibeltran05.alwaysdata.net';

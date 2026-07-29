import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.calendario.finanzas',
  appName: 'Calendario Finanzas',
  // El APK empaqueta el build de Vite. Genera 'dist' con: npm run build:apk
  webDir: 'dist',
  android: {
    // Permite las llamadas al backend de producción por HTTPS.
    allowMixedContent: false
  }
};

export default config;

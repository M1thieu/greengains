import { defineConfig } from 'astro/config';
import tailwind from '@astrojs/tailwind';

export default defineConfig({
  site: 'https://greengains.app',
  integrations: [tailwind()],
  output: 'static',
});

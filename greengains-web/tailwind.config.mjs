/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,ts,tsx}'],
  theme: {
    extend: {
      colors: {
        bg:        '#0f1a1e',
        surface:   '#111f24',
        border:    '#1e2f35',
        primary:   '#10b981',
        'primary-dim': '#059669',
        muted:     '#64748b',
        light:     '#fbbf24',
        movement:  '#14b8a6',
        pressure:  '#0ea5e9',
        quality:   '#10b981',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
      },
    },
  },
  plugins: [],
};

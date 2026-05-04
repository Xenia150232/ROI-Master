import { defineConfig } from 'vite';

// Pure static HTML/JS/CSS app — no framework build step required.
// Run `npm run dev` for local development or open index.html directly in a browser.
export default defineConfig({
  build: {
    rollupOptions: {
      input: 'index.html',
    },
  },
});

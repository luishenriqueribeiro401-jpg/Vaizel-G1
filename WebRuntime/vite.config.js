import { defineConfig } from 'vite';
export default defineConfig({
  build: {
    target: 'es2022',
    outDir: 'dist',
    emptyOutDir: true,
    lib: {entry:'g1_runtime.js', formats:['es'],fileName:()=> 'vaizel-runtime.js'},
    rollupOptions:{output:{inlineDynamicImports:true}},
    minify: false
  }
});

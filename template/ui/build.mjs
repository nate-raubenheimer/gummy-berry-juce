#!/usr/bin/env node
// ui/build.mjs — esbuild bundling for the WebView UI (8.2 / AUD-88).
//
// Bundles ui/js/main.js -- which imports the JUCE frontend relay library via
// a relative "./juce/index.js" ES import (copied from the JUCE checkout at
// CMake configure time; see CMakeLists.txt's file(COPY ...) step, never
// edited by hand) -- into a single dist/main.js, and ui/css/main.css into
// dist/main.css.
//
// CMakeLists.txt runs `npm install` + `npm run build` synchronously at
// configure time, because juce_add_binary_data embeds file contents when
// CMake configures, so the bundle must already exist on disk before that
// call runs. A CMake custom command additionally reruns this script at BUILD
// time whenever ui/js or ui/css change, so `cmake --build` alone (no
// reconfigure) picks up UI edits and the embedded BinaryData gets refreshed.
//
// `npm run watch` keeps dist/ live for disk-served dev iteration via
// GB_UI_DIR (see AGENTS.md / src/PluginEditor.cpp's getResource()).

import { build, context } from 'esbuild';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs';

const here = path.dirname(fileURLToPath(import.meta.url));
const distDir = path.join(here, 'dist');
const watch = process.argv.includes('--watch');

fs.mkdirSync(distDir, { recursive: true });

const jsOpts = {
  entryPoints: [path.join(here, 'js/main.js')],
  outfile: path.join(distDir, 'main.js'),
  bundle: true,
  platform: 'browser',
  format: 'iife',
  target: ['es2020'],
  sourcemap: true,
  logLevel: 'info',
};

const cssOpts = {
  entryPoints: [path.join(here, 'css/main.css')],
  outfile: path.join(distDir, 'main.css'),
  bundle: true,
  target: ['es2020'],
  sourcemap: true,
  logLevel: 'info',
};

if (watch) {
  const jsCtx = await context(jsOpts);
  const cssCtx = await context(cssOpts);
  await jsCtx.watch();
  await cssCtx.watch();
  console.log('GummyPlugin UI: watching for changes (Ctrl+C to stop)');
} else {
  await build(jsOpts);
  await build(cssOpts);
  console.log('GummyPlugin UI: build complete ->', distDir);
}

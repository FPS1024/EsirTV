<template>
  <div v-cloak>
    <router-view />
  </div>
</template>

<script setup>
import { onMounted } from 'vue';
import { EsirtvApi } from './lib/api.js';

function getFontFormatByFilename(filename) {
  const lower = String(filename || '').toLowerCase();
  if (lower.endsWith('.woff2')) return 'woff2';
  if (lower.endsWith('.woff')) return 'woff';
  if (lower.endsWith('.otf')) return 'opentype';
  if (lower.endsWith('.ttf')) return 'truetype';
  return '';
}

function clearUiFont() {
  const style = document.getElementById('es-ui-font-style');
  if (style) {
    style.remove();
  }
  document.documentElement.style.removeProperty('--es-font-family');
}

function applyUiFont(filename) {
  const file = String(filename || '').trim();
  if (!file) {
    clearUiFont();
    return;
  }

  const family = file.replace(/\.[^.]+$/, '');
  const url = `/fonts/${encodeURIComponent(file)}`;
  const format = getFontFormatByFilename(file);
  const src = format ? `url("${url}") format("${format}")` : `url("${url}")`;

  let style = document.getElementById('es-ui-font-style');
  if (!style) {
    style = document.createElement('style');
    style.id = 'es-ui-font-style';
    document.head.appendChild(style);
  }
  style.textContent = `@font-face{font-family:"${family}";src:${src};font-display:swap;}`;
  document.documentElement.style.setProperty(
    '--es-font-family',
    `"${family}", system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif`,
  );
}

onMounted(async () => {
  try {
    const settings = await EsirtvApi.getSettings();
    applyUiFont(settings && settings.uiFont ? settings.uiFont : '');
  } catch (_) {
    // ignore
  }
});
</script>

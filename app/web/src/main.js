import { createApp } from 'vue';
import { createRouter, createWebHistory } from 'vue-router';
import { createI18n } from 'vue-i18n';
import App from './App.vue';
import routes from './router.js';
import './style.css';
import { messages, normalizeLocale } from './i18n/index.js';

async function bootstrap() {
  let locale = 'zh-CN';
  try {
    const res = await fetch('/api/settings');
    if (res.ok) {
      const data = await res.json();
      locale = normalizeLocale(data && data.uiLang);
    }
  } catch (_) {
    // ignore
  }

  document.documentElement.lang = locale;

  const i18n = createI18n({
    legacy: false,
    locale,
    fallbackLocale: 'zh-CN',
    messages,
  });

  const router = createRouter({
    history: createWebHistory(),
    routes,
    scrollBehavior(to) {
      if (to.meta && typeof to.meta.scrollTop === 'number') {
        return { top: to.meta.scrollTop };
      }
      return { top: 0 };
    },
  });

  createApp(App).use(i18n).use(router).mount('#app');
}

bootstrap();

import { createApp } from 'vue';
import { createRouter, createWebHistory } from 'vue-router';
import App from './App.vue';
import routes from './router.js';
import './style.css';

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

createApp(App).use(router).mount('#app');

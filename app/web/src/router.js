import HomeView from './views/HomeView.vue';
import DetailView from './views/DetailView.vue';
import SettingsView from './views/SettingsView.vue';
import NotFoundView from './views/NotFoundView.vue';

function redirectLegacyDetailRoute(to) {
  const site = typeof to.query.site === 'string' ? to.query.site : '';
  const vodId = typeof to.query.vod_id === 'string' ? to.query.vod_id : '';
  if (site && vodId) {
    return { name: 'detail', params: { site, vodId } };
  }
  return { name: 'home' };
}

export default [
  { path: '/', name: 'home', component: HomeView },
  { path: '/settings', name: 'settings', component: SettingsView },
  { path: '/detail/:site/:vodId', name: 'detail', component: DetailView, props: true },

  // Legacy URLs from the old multi-page frontend
  { path: '/index.html', redirect: { name: 'home' } },
  { path: '/settings.html', redirect: { name: 'settings' } },
  { path: '/detail.html', redirect: redirectLegacyDetailRoute },

  { path: '/:pathMatch(.*)*', name: 'notFound', component: NotFoundView },
];


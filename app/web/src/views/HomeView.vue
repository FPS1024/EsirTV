<template>
  <div>
    <header class="sticky top-0 z-50 border-b border-white/10 bg-[#111]/80 backdrop-blur">
      <div class="px-4 md:px-6 py-4 flex items-center justify-between gap-4">
        <div class="flex items-center gap-4 md:gap-8 min-w-0">
          <h1
            class="text-2xl font-bold tracking-wide bg-gradient-to-r from-cyan-300 via-sky-300 to-blue-500 bg-clip-text text-transparent cursor-pointer select-none"
            @click="resetHome"
          >
            EsirTV
          </h1>
          <div class="hidden md:block text-slate-400 text-sm truncate">
            {{ currentTypeName }}
          </div>
        </div>

        <div class="flex items-center gap-2 md:gap-3">
          <select
            v-if="sites.length"
            v-model="site"
            @change="switchSite(site)"
            class="bg-black/30 border border-white/10 rounded-lg py-2 px-3 text-sm text-slate-200 focus:outline-none focus:ring-2 focus:ring-blue-500/30"
          >
            <option v-for="s in sites" :key="s.key || s.name" :value="s.key || s.name">
              {{ s.name }}
            </option>
          </select>
          <div class="flex items-center bg-black/30 border border-white/10 rounded-lg overflow-hidden">
            <input
              v-model.trim="keyword"
              @keyup.enter="searchMovies"
              type="text"
              placeholder="搜索影片..."
              class="bg-transparent py-2 px-3 text-sm w-32 sm:w-44 md:w-64 focus:outline-none"
            />
            <button @click="searchMovies" class="bg-blue-600 hover:bg-blue-500 px-3 py-2 text-sm">
              <i class="fa-solid fa-magnifying-glass mr-1"></i>搜索
            </button>
          </div>
          <router-link to="/settings" class="bg-black/30 hover:bg-black/40 border border-white/10 px-3 py-2 rounded-lg text-sm">
            <i class="fa-solid fa-gear"></i>
            <span class="hidden md:inline ml-1">设置</span>
          </router-link>
        </div>
      </div>

      <!-- Menu bar 1: history & favorites -->
      <div class="px-4 md:px-6 pb-2">
        <div class="flex items-center gap-6 overflow-x-auto whitespace-nowrap scrollbar-none">
          <button
            class="text-sm tracking-wide transition border-b-2 pb-1"
            :class="currentType === HISTORY_TYPE_ID ? 'text-white border-blue-500' : 'text-slate-300 border-transparent hover:text-white'"
            @click="filterType(HISTORY_TYPE_ID)"
          >
            <i class="fa-solid fa-clock-rotate-left mr-1"></i>历史记录
          </button>
          <button
            class="text-sm tracking-wide transition border-b-2 pb-1"
            :class="currentType === FAVORITES_TYPE_ID ? 'text-white border-blue-500' : 'text-slate-300 border-transparent hover:text-white'"
            @click="filterType(FAVORITES_TYPE_ID)"
          >
            <i class="fa-solid fa-star mr-1"></i>收藏
          </button>
        </div>
      </div>

      <!-- Menu bar 2: categories -->
      <div class="px-4 md:px-6 pb-3">
        <div class="flex items-center gap-6 overflow-x-auto whitespace-nowrap scrollbar-none">
          <button
            v-for="type in types"
            :key="type.type_id"
            class="text-sm tracking-wide transition border-b-2 pb-1"
            :class="currentType === Number(type.type_id) ? 'text-white border-blue-500' : 'text-slate-300 border-transparent hover:text-white'"
            @click="filterType(Number(type.type_id))"
          >
            {{ type.type_name }}
          </button>
        </div>
      </div>
    </header>

    <main class="min-h-[calc(100vh-140px)] bg-[#111]">
      <div class="max-w-screen-2xl mx-auto p-4 md:p-6">
      <div v-if="errorMsg" class="mb-4 rounded-lg border border-amber-600/40 bg-amber-950/30 px-4 py-3 text-amber-200">
        {{ errorMsg }}
        <router-link to="/settings" class="underline ml-2">去设置</router-link>
      </div>

      <div class="flex items-center justify-between mb-3">
        <h2 class="text-xl md:text-2xl font-semibold">{{ currentTypeName }}</h2>
        <div class="flex items-center gap-2">
          <span v-if="searchMode" class="text-xs md:text-sm px-2 py-1 rounded bg-blue-500/20 border border-blue-500/30 text-blue-200">
            搜索中：{{ activeKeyword }}
          </span>
          <button v-if="searchMode" @click="clearSearch" class="text-xs md:text-sm px-2 py-1 rounded bg-slate-800 hover:bg-slate-700">
            清空搜索
          </button>
          <div class="text-slate-400 text-sm">第 {{ currentPage }} / {{ pagecount }} 页</div>
        </div>
      </div>

      <div class="es-poster-grid">
        <article
          v-for="item in movies"
          :key="item.id"
          class="es-grid-card"
          @click="goDetail(item)"
          :title="item.title"
        >
          <img :src="item.poster" :alt="item.title" class="es-grid-img" loading="lazy" />
          <div class="es-grid-info">
            <span class="es-grid-title">{{ item.title }}</span>
          </div>
        </article>
      </div>

      <div v-if="isLoading" class="text-center text-slate-400 py-8">
        <i class="fa-solid fa-spinner fa-spin mr-2"></i>加载中...
      </div>

      <div v-if="!isLoading && hasMore" class="text-center py-8">
        <button v-if="!autoLoadSupported" @click="loadMore" class="bg-blue-600 hover:bg-blue-500 px-6 py-2 rounded-lg">
          加载更多
        </button>
        <p v-else class="text-slate-400 text-sm">正在自动加载更多...</p>
      </div>
      <div ref="loadMoreSentinel" class="h-2"></div>
      </div>
    </main>
  </div>
</template>

<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { EsirtvApi } from '../lib/api.js';
import { getJSON, setJSON } from '../lib/storage.js';

const route = useRoute();
const router = useRouter();

const HOME_STATE_KEY = 'esirtv.homeState';
const HOME_SAVE_DELAY_MS = 200;
const HISTORY_TYPE_ID = -1;
const FAVORITES_TYPE_ID = -2;

const sites = ref([]);
const site = ref('');
const types = ref([]);
const currentType = ref(HISTORY_TYPE_ID);
const movies = ref([]);
const keyword = ref('');
const activeKeyword = ref('');
const searchMode = ref(false);
const currentPage = ref(1);
const pagecount = ref(1);
const hasMore = ref(false);
const isLoading = ref(false);
const errorMsg = ref('');

const autoLoadSupported = typeof window.IntersectionObserver !== 'undefined';
const loadMoreSentinel = ref(null);
let loadMoreObserver = null;
let saveTimer = null;

const currentTypeName = computed(() => {
  if (searchMode.value) {
    return `搜索结果：${activeKeyword.value}`;
  }
  if (currentType.value === HISTORY_TYPE_ID) {
    return '历史记录';
  }
  if (currentType.value === FAVORITES_TYPE_ID) {
    return '我的收藏';
  }
  const target = types.value.find((item) => Number(item.type_id) === Number(currentType.value));
  return target ? `${target.type_name} 精选` : '精选';
});

function remapPosterIfNeeded(list) {
  return (list || []).map((item) => {
    if (!item || typeof item !== 'object') {
      return item;
    }
    const rawPoster = item.vod_pic || item.poster || '';
    return {
      ...item,
      poster: rawPoster ? EsirtvApi.getPosterUrl(rawPoster) : '',
    };
  });
}

function mapMovies(list) {
  return (list || []).map((item) => ({
    ...item,
    id: item.vod_id,
    vod_id: item.vod_id,
    title: item.vod_name,
    poster: EsirtvApi.getPosterUrl(item.vod_pic),
  }));
}

function mapRecordItems(list) {
  return (list || []).map((item) => ({
    id: `${item.site}:${item.vodId}`,
    vod_id: item.vodId,
    vod_name: item.title,
    vod_pic: item.poster || '',
    title: item.title,
    poster: item.poster ? EsirtvApi.getPosterUrl(item.poster) : '',
    site: item.site,
    recordUpdatedAt: item.updatedAt || 0,
  }));
}

function loadHomeState() {
  return getJSON(HOME_STATE_KEY, {
    site: '',
    typeId: HISTORY_TYPE_ID,
    keyword: '',
  });
}

function saveHomeState(immediate = false) {
  const persist = () => {
    setJSON(HOME_STATE_KEY, {
      site: site.value || '',
      typeId: Number(currentType.value),
      keyword: keyword.value || '',
      activeKeyword: searchMode.value ? activeKeyword.value : '',
      searchMode: Boolean(searchMode.value),
      currentPage: Number(currentPage.value || 1),
      pagecount: Number(pagecount.value || 1),
      hasMore: Boolean(hasMore.value),
      movies: Array.isArray(movies.value) ? movies.value : [],
      scrollY: Math.max(0, Number(window.scrollY || 0)),
      updatedAt: Date.now(),
    });
  };

  if (immediate) {
    if (saveTimer) {
      clearTimeout(saveTimer);
      saveTimer = null;
    }
    persist();
    return;
  }

  if (saveTimer) {
    clearTimeout(saveTimer);
  }
  saveTimer = setTimeout(() => {
    saveTimer = null;
    persist();
  }, HOME_SAVE_DELAY_MS);
}

function canRestoreHomeState(saved, expectedSite) {
  if (!saved || typeof saved !== 'object') {
    return false;
  }
  if (!expectedSite || saved.site !== expectedSite) {
    return false;
  }
  if (!Array.isArray(saved.movies) || saved.movies.length === 0) {
    return false;
  }
  if (saved.searchMode && !saved.activeKeyword) {
    return false;
  }
  return true;
}

function restoreHomeState(saved) {
  currentType.value = Number(saved.typeId);
  keyword.value = saved.keyword || '';
  activeKeyword.value = saved.activeKeyword || '';
  searchMode.value = Boolean(saved.searchMode);
  currentPage.value = Number(saved.currentPage || 1);
  pagecount.value = Number(saved.pagecount || 1);
  hasMore.value = Boolean(saved.hasMore);
  movies.value = remapPosterIfNeeded(saved.movies);
  nextTick(() => {
    window.scrollTo({ top: Math.max(0, Number(saved.scrollY || 0)), behavior: 'auto' });
  });
}

function setupAutoLoadObserver() {
  if (!autoLoadSupported || loadMoreObserver) {
    return;
  }
  const target = loadMoreSentinel.value;
  if (!target) {
    return;
  }
  loadMoreObserver = new window.IntersectionObserver((entries) => {
    const visible = entries.some((entry) => entry.isIntersecting);
    if (visible) {
      triggerAutoLoadIfNeeded();
    }
  }, {
    root: null,
    rootMargin: '300px 0px',
    threshold: 0.01,
  });
  loadMoreObserver.observe(target);
}

function tearDownAutoLoadObserver() {
  if (loadMoreObserver) {
    loadMoreObserver.disconnect();
    loadMoreObserver = null;
  }
}

function triggerAutoLoadIfNeeded() {
  if (!autoLoadSupported || isLoading.value || !hasMore.value) {
    return;
  }
  if (currentType.value === HISTORY_TYPE_ID || currentType.value === FAVORITES_TYPE_ID) {
    return;
  }
  const target = loadMoreSentinel.value;
  if (!target) {
    return;
  }
  const rect = target.getBoundingClientRect();
  if (rect.top <= (window.innerHeight + 300)) {
    loadMore();
  }
}

function onScrollSave() {
  saveHomeState(false);
}

async function fetchSites() {
  const data = await EsirtvApi.getSites();
  sites.value = data;
  if (!site.value && data.length > 0) {
    site.value = data[0].key || data[0].name;
  }
}

async function fetchTypes() {
  types.value = await EsirtvApi.getTypes(site.value);
}

async function fetchMovies(page = 1, append = false) {
  isLoading.value = true;
  try {
    const data = await EsirtvApi.getList(site.value, currentType.value, page);
    const mapped = mapMovies(data.list);
    movies.value = append ? [...movies.value, ...mapped] : mapped;
    currentPage.value = Number(data.page || page);
    pagecount.value = Number(data.pagecount || 1);
    hasMore.value = Boolean(data.hasMore);
    saveHomeState(false);
  } finally {
    isLoading.value = false;
    nextTick(() => triggerAutoLoadIfNeeded());
  }
}

async function fetchSearchMovies(page = 1, append = false) {
  isLoading.value = true;
  try {
    const data = await EsirtvApi.search(site.value, activeKeyword.value, page);
    const mapped = mapMovies(data.list);
    movies.value = append ? [...movies.value, ...mapped] : mapped;
    currentPage.value = Number(data.page || page);
    pagecount.value = Number(data.pagecount || 1);
    hasMore.value = Boolean(data.hasMore);
    saveHomeState(false);
  } finally {
    isLoading.value = false;
    nextTick(() => triggerAutoLoadIfNeeded());
  }
}

async function fetchHistory() {
  isLoading.value = true;
  try {
    const list = await EsirtvApi.getHistory(site.value, 200);
    movies.value = mapRecordItems(list);
    currentPage.value = 1;
    pagecount.value = 1;
    hasMore.value = false;
    saveHomeState(true);
  } finally {
    isLoading.value = false;
  }
}

async function fetchFavorites() {
  isLoading.value = true;
  try {
    const list = await EsirtvApi.getFavorites(site.value);
    movies.value = mapRecordItems(list);
    currentPage.value = 1;
    pagecount.value = 1;
    hasMore.value = false;
    saveHomeState(true);
  } finally {
    isLoading.value = false;
  }
}

async function loadCurrentList(firstPage = 1, append = false) {
  errorMsg.value = '';
  if (currentType.value === HISTORY_TYPE_ID) {
    await fetchHistory();
    return;
  }
  if (currentType.value === FAVORITES_TYPE_ID) {
    await fetchFavorites();
    return;
  }
  if (searchMode.value) {
    await fetchSearchMovies(firstPage, append);
    return;
  }
  await fetchMovies(firstPage, append);
}

async function filterType(typeId) {
  if (isLoading.value) {
    return;
  }
  currentType.value = Number(typeId);
  searchMode.value = false;
  activeKeyword.value = '';
  currentPage.value = 1;
  pagecount.value = 1;
  hasMore.value = false;
  movies.value = [];
  await loadCurrentList(1, false);
}

async function switchSite(nextSite) {
  if (!nextSite || isLoading.value) {
    return;
  }
  site.value = nextSite;
  currentType.value = HISTORY_TYPE_ID;
  searchMode.value = false;
  activeKeyword.value = '';
  keyword.value = '';
  currentPage.value = 1;
  pagecount.value = 1;
  hasMore.value = false;
  movies.value = [];
  await fetchTypes();
  await loadCurrentList(1, false);
}

async function searchMovies() {
  const kw = (keyword.value || '').trim();
  if (!kw || isLoading.value) {
    return;
  }
  activeKeyword.value = kw;
  searchMode.value = true;
  currentType.value = 0;
  currentPage.value = 1;
  movies.value = [];
  await loadCurrentList(1, false);
}

async function clearSearch() {
  searchMode.value = false;
  activeKeyword.value = '';
  keyword.value = '';
  currentPage.value = 1;
  movies.value = [];
  await loadCurrentList(1, false);
}

async function loadMore() {
  if (!hasMore.value || isLoading.value) {
    return;
  }
  const next = Number(currentPage.value || 1) + 1;
  await loadCurrentList(next, true);
}

function goDetail(item) {
  const itemSite = item.site || site.value;
  const vodId = item.vod_id || item.id;
  if (!itemSite || !vodId) {
    return;
  }
  router.push({ name: 'detail', params: { site: itemSite, vodId } });
}

async function resetHome() {
  await filterType(HISTORY_TYPE_ID);
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

async function init() {
  try {
    const saved = loadHomeState();
    const urlSite = typeof route.query.site === 'string' ? route.query.site : '';

    await fetchSites();
    if (urlSite) {
      site.value = urlSite;
    } else if (saved.site) {
      site.value = saved.site;
    }

    if (!site.value && sites.value.length > 0) {
      site.value = sites.value[0].key || sites.value[0].name;
    }

    await fetchTypes();
    setupAutoLoadObserver();

    if (canRestoreHomeState(saved, site.value)) {
      restoreHomeState(saved);
      nextTick(() => triggerAutoLoadIfNeeded());
      return;
    }

    await loadCurrentList(1, false);
  } catch (error) {
    errorMsg.value = error?.message || '加载失败，请先到设置页配置数据源链接。';
  }
}

watch([site, currentType, keyword, activeKeyword, searchMode, currentPage, pagecount, hasMore, movies], () => {
  saveHomeState(false);
});

onMounted(() => {
  window.addEventListener('scroll', onScrollSave, { passive: true });
  init();
});

onBeforeUnmount(() => {
  window.removeEventListener('scroll', onScrollSave);
  tearDownAutoLoadObserver();
  saveHomeState(true);
});

defineExpose({ HISTORY_TYPE_ID, FAVORITES_TYPE_ID });
</script>

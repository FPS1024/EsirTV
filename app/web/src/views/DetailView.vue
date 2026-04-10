<template>
  <main class="max-w-7xl mx-auto p-4 md:p-6">
    <div class="mb-4 flex items-center justify-between gap-3">
      <router-link :to="backHomeTo" class="inline-flex items-center gap-2 bg-slate-800 hover:bg-slate-700 px-3 py-2 rounded-lg">
        <i class="fa-solid fa-arrow-left"></i>返回
      </router-link>
      <router-link to="/settings" class="inline-flex items-center gap-2 bg-slate-800 hover:bg-slate-700 px-3 py-2 rounded-lg text-sm">
        <i class="fa-solid fa-gear"></i>设置
      </router-link>
    </div>

    <div v-if="errorMsg" class="mb-4 rounded-lg border border-rose-600/40 bg-rose-950/30 px-4 py-3 text-rose-200">
      {{ errorMsg }}
    </div>

    <section class="min-h-[60vh]">
      <div class="bg-black rounded-xl overflow-hidden mb-6">
        <div ref="playerEl" class="w-full h-[60vh] bg-black"></div>
      </div>

      <div v-if="ready" class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div class="lg:col-span-2">
          <div class="flex items-start justify-between gap-3 mb-3">
            <h1 class="text-3xl font-bold">{{ title }}</h1>
            <button
              class="inline-flex items-center gap-2 rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 text-sm hover:border-amber-400"
              :class="{ 'border-amber-400': favorited }"
              @click="toggleFavorite"
            >
              <i :class="favorited ? 'fa-solid fa-star text-amber-400' : 'fa-regular fa-star'"></i>
              <span>{{ favorited ? '已收藏' : '收藏' }}</span>
            </button>
          </div>
          <p class="text-slate-400 mb-4">{{ meta }}</p>

          <div class="glass-effect rounded-xl p-5 mb-6 border border-slate-800">
            <h2 class="text-lg font-semibold mb-2">简介</h2>
            <p class="text-slate-300 leading-7 whitespace-pre-wrap">{{ desc }}</p>
          </div>

          <h2 class="text-lg font-semibold mb-3">线路</h2>
          <div class="flex flex-wrap gap-2 mb-6">
            <button
              v-for="(s, idx) in sources"
              :key="`${s.name}:${idx}`"
              class="px-4 py-2 rounded border border-slate-700 bg-slate-900 hover:border-blue-400"
              :class="{ 'border-blue-400 text-blue-300': idx === sourceIndex }"
              @click="selectSource(idx)"
            >
              {{ s.name }}
            </button>
          </div>

          <h2 class="text-lg font-semibold mb-3">选集</h2>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="(ep, idx) in currentEpisodes"
              :key="`${ep.url}:${idx}`"
              class="px-4 py-2 rounded border border-slate-700 bg-slate-900 hover:border-blue-400"
              :class="{ 'border-blue-400 text-blue-300': ep.url === selectedPlayUrl }"
              @click="selectEpisode(ep)"
            >
              {{ ep.name || `第${idx + 1}集` }}
            </button>
            <span v-if="currentEpisodes.length === 0" class="text-slate-400">该线路暂无可播放选集</span>
          </div>
        </div>

        <aside>
          <div class="glass-effect rounded-xl p-5 border border-slate-800">
            <h2 class="text-lg font-semibold mb-2">播放信息</h2>
            <p class="text-slate-300 text-sm">{{ playInfo }}</p>
          </div>
        </aside>
      </div>

      <div v-else class="text-center text-slate-400 py-8">
        <i class="fa-solid fa-spinner fa-spin mr-2"></i>加载中...
      </div>
    </section>
  </main>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { EsirtvApi } from '../lib/api.js';
import { createVideoPlayer, parseSources } from '../lib/player.js';

const props = defineProps({
  site: { type: String, required: true },
  vodId: { type: String, required: true },
});

const router = useRouter();

const SAVE_INTERVAL_MS = 5000;

const errorMsg = ref('');
const ready = ref(false);

const title = ref('');
const poster = ref('');
const typeName = ref('');
const vodYear = ref('');
const vodArea = ref('');
const desc = ref('');
const favorited = ref(false);

const sources = ref([]);
const sourceIndex = ref(0);
const selectedEpisodeName = ref('');
const selectedPlayUrl = ref('');
const playInfo = ref('加载中...');

const playerEl = ref(null);
let player = null;
let lastSaveAt = 0;
let savedEntry = null;

const meta = computed(() => [vodYear.value, vodArea.value, typeName.value].filter(Boolean).join(' / '));
const currentEpisodes = computed(() => (sources.value[sourceIndex.value]?.episodes || []));
const backHomeTo = computed(() => ({ name: 'home', query: props.site ? { site: props.site } : {} }));

async function refreshFavoriteState() {
  const item = await EsirtvApi.getFavoriteItem(props.site, props.vodId);
  favorited.value = Boolean(item);
}

async function toggleFavorite() {
  const payload = {
    site: props.site,
    vodId: props.vodId,
    title: title.value,
    poster: poster.value,
    typeName: typeName.value,
    vodYear: vodYear.value,
    vodArea: vodArea.value,
  };

  if (favorited.value) {
    await EsirtvApi.removeFavorite(props.site, props.vodId);
    favorited.value = false;
    return;
  }

  await EsirtvApi.saveFavorite(payload);
  favorited.value = true;
}

function saveCurrentHistory(force = false) {
  const video = player?.getVideoElement?.();
  if (!video || !props.site || !props.vodId || !selectedPlayUrl.value) {
    return;
  }

  const now = Date.now();
  if (!force && (now - lastSaveAt) < SAVE_INTERVAL_MS) {
    return;
  }

  const source = sources.value[sourceIndex.value] || { name: '默认线路' };
  const payload = {
    site: props.site,
    vodId: props.vodId,
    title: title.value,
    poster: poster.value,
    typeName: typeName.value,
    vodYear: vodYear.value,
    vodArea: vodArea.value,
    sourceIndex: sourceIndex.value,
    sourceName: source.name,
    episodeName: selectedEpisodeName.value,
    playUrl: selectedPlayUrl.value,
    progressSec: Number(video.currentTime || 0),
    durationSec: Number(video.duration || 0),
  };

  lastSaveAt = now;
  EsirtvApi.saveHistory(payload).catch((error) => {
    console.warn('保存历史记录失败:', error?.message || error);
  });
}

function selectSource(idx) {
  const s = sources.value[idx];
  if (!s) {
    return;
  }
  sourceIndex.value = idx;

  const episodes = s.episodes || [];
  if (episodes.length === 0) {
    return;
  }

  const sameSourceAsSaved = Boolean(
    savedEntry
      && (savedEntry.sourceIndex === idx || savedEntry.sourceName === s.name),
  );
  const savedEpisode = sameSourceAsSaved
    ? episodes.find((item) => item.name === savedEntry.episodeName || item.url === savedEntry.playUrl)
    : null;
  selectEpisode(savedEpisode || episodes[0], sameSourceAsSaved ? savedEntry : null);
}

function selectEpisode(ep, resumeEntry = null) {
  if (!ep || !ep.url) {
    return;
  }
  selectedEpisodeName.value = ep.name || '';
  selectedPlayUrl.value = ep.url;
  playInfo.value = `当前播放：${ep.name || '未命名'}`;

  const resumeSec = resumeEntry ? Number(resumeEntry.progressSec || 0) : 0;
  player?.play(ep.url, resumeSec);
  saveCurrentHistory(true);
}

function bindPlayerEvents() {
  const video = player?.getVideoElement?.();
  if (!video) {
    return;
  }
  video.addEventListener('timeupdate', () => saveCurrentHistory(false));
  video.addEventListener('pause', () => saveCurrentHistory(true));
  video.addEventListener('ended', () => saveCurrentHistory(true));
}

async function init() {
  if (!props.site || !props.vodId) {
    errorMsg.value = '缺少 site 或 vodId 参数，无法加载详情。';
    return;
  }

  try {
    const el = playerEl.value;
    if (!el) {
      throw new Error('播放器初始化失败');
    }
    player = createVideoPlayer(el, (msg) => {
      playInfo.value = msg;
    });
    bindPlayerEvents();

    const data = await EsirtvApi.getDetail(props.site, props.vodId);
    savedEntry = await EsirtvApi.getHistoryItem(props.site, props.vodId);

    title.value = data.vod_name || '未命名视频';
    poster.value = data.vod_pic || '';
    typeName.value = data.type_name || '';
    vodYear.value = data.vod_year || '';
    vodArea.value = data.vod_area || '';
    desc.value = data.vod_content || '暂无简介';

    sources.value = parseSources(data.vod_play_from, data.vod_play_url);
    if (sources.value.length === 0) {
      throw new Error('该视频暂无可用播放线路');
    }

    await refreshFavoriteState();
    ready.value = true;

    selectSource(0);
  } catch (error) {
    errorMsg.value = error?.message || '加载详情失败';
  }
}

onMounted(init);

onBeforeUnmount(() => {
  saveCurrentHistory(true);
  player?.destroy();
});
</script>

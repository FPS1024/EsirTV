const SAVE_INTERVAL_MS = 5000;

const detailState = {
  site: '',
  vodId: '',
  title: '',
  poster: '',
  typeName: '',
  vodYear: '',
  vodArea: '',
  sources: [],
  sourceIndex: 0,
  selectedEpisodeName: '',
  selectedPlayUrl: '',
  lastSaveAt: 0,
  player: null,
  favorited: false,
};

function showError(message) {
  const box = document.getElementById('errorBox');
  box.textContent = message;
  box.classList.remove('hidden');
}

function setPlayInfo(text) {
  document.getElementById('playInfo').textContent = text;
}

function setFavoriteButtonState(favorited) {
  const btn = document.getElementById('favoriteBtn');
  const icon = btn.querySelector('i');
  const text = btn.querySelector('span');

  detailState.favorited = Boolean(favorited);
  icon.className = favorited ? 'fa-solid fa-star text-amber-400' : 'fa-regular fa-star';
  text.textContent = favorited ? '已收藏' : '收藏';
  btn.classList.toggle('border-amber-400', favorited);
}

async function refreshFavoriteState() {
  const item = await window.EsirtvApi.getFavoriteItem(detailState.site, detailState.vodId);
  setFavoriteButtonState(Boolean(item));
}

async function toggleFavorite() {
  const payload = {
    site: detailState.site,
    vodId: detailState.vodId,
    title: detailState.title,
    poster: detailState.poster,
    typeName: detailState.typeName,
    vodYear: detailState.vodYear,
    vodArea: detailState.vodArea,
  };

  if (detailState.favorited) {
    await window.EsirtvApi.removeFavorite(detailState.site, detailState.vodId);
    setFavoriteButtonState(false);
    return;
  }

  await window.EsirtvApi.saveFavorite(payload);
  setFavoriteButtonState(true);
}

function saveCurrentHistory(force = false) {
  const player = document.getElementById('player');
  if (!detailState.site || !detailState.vodId || !detailState.selectedPlayUrl) {
    return;
  }

  const now = Date.now();
  if (!force && (now - detailState.lastSaveAt) < SAVE_INTERVAL_MS) {
    return;
  }

  const source = detailState.sources[detailState.sourceIndex] || { name: '默认线路' };
  const payload = {
    site: detailState.site,
    vodId: detailState.vodId,
    title: detailState.title,
    poster: detailState.poster,
    typeName: detailState.typeName,
    vodYear: detailState.vodYear,
    vodArea: detailState.vodArea,
    sourceIndex: detailState.sourceIndex,
    sourceName: source.name,
    episodeName: detailState.selectedEpisodeName,
    playUrl: detailState.selectedPlayUrl,
    progressSec: Number(player.currentTime || 0),
    durationSec: Number(player.duration || 0),
  };

  detailState.lastSaveAt = now;
  window.EsirtvApi.saveHistory(payload).catch((error) => {
    console.warn('保存历史记录失败:', error.message || error);
  });
}

function renderSources(savedEntry) {
  const container = document.getElementById('sources');
  container.innerHTML = '';

  if (detailState.sources.length === 0) {
    container.innerHTML = '<span class="text-slate-400">暂无可用线路</span>';
    return;
  }

  let initialSourceIndex = 0;
  if (savedEntry) {
    if (typeof savedEntry.sourceIndex === 'number' && detailState.sources[savedEntry.sourceIndex]) {
      initialSourceIndex = savedEntry.sourceIndex;
    } else {
      const indexByName = detailState.sources.findIndex((item) => item.name === savedEntry.sourceName);
      if (indexByName >= 0) {
        initialSourceIndex = indexByName;
      }
    }
  }

  detailState.sources.forEach((source, idx) => {
    const btn = document.createElement('button');
    btn.className = 'px-4 py-2 rounded border border-slate-700 bg-slate-900 hover:border-blue-400';
    btn.textContent = source.name;
    btn.addEventListener('click', () => selectSource(idx, savedEntry));
    container.appendChild(btn);

    if (idx === initialSourceIndex) {
      btn.click();
    }
  });
}

function selectSource(sourceIndex, savedEntry) {
  const sourcesBox = document.getElementById('sources');
  const source = detailState.sources[sourceIndex];
  if (!source) {
    return;
  }

  detailState.sourceIndex = sourceIndex;
  Array.from(sourcesBox.children).forEach((node, idx) => {
    node.classList.toggle('border-blue-400', idx === sourceIndex);
    node.classList.toggle('text-blue-300', idx === sourceIndex);
  });

  renderEpisodes(source.episodes, savedEntry);
}

function renderEpisodes(episodes, savedEntry) {
  const container = document.getElementById('episodes');
  container.innerHTML = '';
  const currentSource = detailState.sources[detailState.sourceIndex];
  const sameSourceAsSaved = Boolean(
    savedEntry && currentSource
    && (
      savedEntry.sourceIndex === detailState.sourceIndex
      || savedEntry.sourceName === currentSource.name
    )
  );

  if (episodes.length === 0) {
    container.innerHTML = '<span class="text-slate-400">该线路暂无可播放选集</span>';
    return;
  }

  const savedEpisode = sameSourceAsSaved
    ? episodes.find((item) => item.name === savedEntry.episodeName || item.url === savedEntry.playUrl)
    : null;
  const initialEpisode = savedEpisode || episodes[0];

  episodes.forEach((ep, index) => {
    const btn = document.createElement('button');
    btn.className = 'px-4 py-2 rounded border border-slate-700 bg-slate-900 hover:border-blue-400';
    btn.textContent = ep.name || `第${index + 1}集`;
    btn.addEventListener('click', () => {
      detailState.selectedEpisodeName = ep.name;
      detailState.selectedPlayUrl = ep.url;

      setPlayInfo(`当前播放：${ep.name}`);
      Array.from(container.children).forEach((node) => {
        node.classList.remove('border-blue-400', 'text-blue-300');
      });
      btn.classList.add('border-blue-400', 'text-blue-300');

      const sameAsSaved = sameSourceAsSaved
        && (savedEntry.playUrl === ep.url || savedEntry.episodeName === ep.name);
      const resumeSec = sameAsSaved ? Number(savedEntry.progressSec || 0) : 0;
      detailState.player.play(ep.url, resumeSec);
      saveCurrentHistory(true);
    });
    container.appendChild(btn);

    if (ep.url === initialEpisode.url) {
      btn.click();
    }
  });
}

function bindPlayerEvents() {
  const player = document.getElementById('player');
  player.addEventListener('timeupdate', () => saveCurrentHistory(false));
  player.addEventListener('pause', () => saveCurrentHistory(true));
  player.addEventListener('ended', () => saveCurrentHistory(true));
  window.addEventListener('beforeunload', () => {
    saveCurrentHistory(true);
    if (detailState.player) {
      detailState.player.destroy();
    }
  });
}

async function initDetailPage() {
  const params = new URLSearchParams(window.location.search);
  const site = params.get('site') || '';
  const vodId = params.get('vod_id') || '';

  detailState.site = site;
  detailState.vodId = vodId;

  const backHome = document.getElementById('backHome');
  backHome.href = `./index.html${site ? `?site=${encodeURIComponent(site)}` : ''}`;

  if (!site || !vodId) {
    showError('缺少 site 或 vod_id 参数，无法加载详情。');
    return;
  }

  try {
    const playerEl = document.getElementById('player');
    detailState.player = window.EsirtvPlayer.createVideoPlayer(playerEl, (msg) => setPlayInfo(msg));
    bindPlayerEvents();

    const data = await window.EsirtvApi.getDetail(site, vodId);
    const savedEntry = await window.EsirtvApi.getHistoryItem(site, vodId);

    detailState.title = data.vod_name || '未命名视频';
    detailState.poster = data.vod_pic || '';
    detailState.typeName = data.type_name || '';
    detailState.vodYear = data.vod_year || '';
    detailState.vodArea = data.vod_area || '';

    document.getElementById('title').textContent = detailState.title;
    document.getElementById('meta').textContent = [data.vod_year, data.vod_area, data.type_name].filter(Boolean).join(' / ');
    document.getElementById('desc').textContent = data.vod_content || '暂无简介';

    detailState.sources = window.EsirtvPlayer.parseSources(data.vod_play_from, data.vod_play_url);
    if (detailState.sources.length === 0) {
      throw new Error('该视频暂无可用播放线路');
    }

    const favoriteBtn = document.getElementById('favoriteBtn');
    favoriteBtn.addEventListener('click', async () => {
      try {
        await toggleFavorite();
      } catch (error) {
        showError(error.message || '收藏操作失败');
      }
    });
    await refreshFavoriteState();

    renderSources(savedEntry);
    document.getElementById('content').classList.remove('hidden');
  } catch (error) {
    showError(error.message || '加载详情失败');
  }
}

initDetailPage();

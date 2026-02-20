(function attachEsirtvApi(global) {
  async function requestJson(url, options = {}) {
    const res = await fetch(url, options);
    const rawText = await res.text();
    let data = {};
    try {
      data = rawText ? JSON.parse(rawText) : {};
    } catch (_) {
      data = { error: rawText || '响应解析失败' };
    }

    if (!res.ok) {
      const detail = data.detail ? `：${data.detail}` : '';
      throw new Error(`${data.error || `请求失败(${res.status})`}${detail}`);
    }
    return data;
  }

  function buildQuery(params) {
    const search = new URLSearchParams();
    Object.entries(params).forEach(([key, value]) => {
      if (value !== undefined && value !== null && value !== '') {
        search.set(key, String(value));
      }
    });
    return search.toString();
  }

  global.EsirtvApi = {
    getPosterUrl(rawUrl) {
      if (!rawUrl) {
        return '';
      }
      return `/api/image?${buildQuery({ url: rawUrl })}`;
    },
    getSites() {
      return requestJson('/api/sites');
    },
    getTypes(site) {
      return requestJson(`/api/types?${buildQuery({ site })}`);
    },
    getList(site, typeId, page = 1) {
      return requestJson(`/api/list?${buildQuery({ site, type_id: typeId, page })}`);
    },
    search(site, keyword, page = 1) {
      return requestJson(`/api/search?${buildQuery({ site, wd: keyword, page })}`);
    },
    getDetail(site, vodId) {
      return requestJson(`/api/detail?${buildQuery({ site, vod_id: vodId })}`);
    },
    getHistory(site, limit = 100) {
      return requestJson(`/api/history?${buildQuery({ site, limit })}`);
    },
    getHistoryItem(site, vodId) {
      return requestJson(`/api/history/item?${buildQuery({ site, vod_id: vodId })}`);
    },
    saveHistory(payload) {
      return requestJson('/api/history', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
    },
    removeHistory(site, vodId) {
      return requestJson(`/api/history?${buildQuery({ site, vod_id: vodId })}`, {
        method: 'DELETE',
      });
    },
    getFavorites(site) {
      return requestJson(`/api/favorites?${buildQuery({ site })}`);
    },
    getFavoriteItem(site, vodId) {
      return requestJson(`/api/favorites/item?${buildQuery({ site, vod_id: vodId })}`);
    },
    saveFavorite(payload) {
      return requestJson('/api/favorites', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
    },
    removeFavorite(site, vodId) {
      return requestJson(`/api/favorites?${buildQuery({ site, vod_id: vodId })}`, {
        method: 'DELETE',
      });
    },
    getSettings() {
      return requestJson('/api/settings');
    },
    saveSettings(configUrl) {
      return requestJson('/api/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ configUrl }),
      });
    },
    testSettings(configUrl) {
      return requestJson('/api/settings/test', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ configUrl }),
      });
    },
  };
}(window));

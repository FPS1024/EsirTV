const express = require('express');
const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');
const zlib = require('zlib');
const Database = require('better-sqlite3');
const { URL } = require('url');

const app = express();
const PORT = Number(process.env.PORT || process.env.APP_PORT || 8080);
const SETTINGS_FILE = process.env.SETTINGS_FILE
  ? path.resolve(process.env.SETTINGS_FILE)
  : path.join(__dirname, '../settings.json');
const FONTS_DIR = process.env.FONTS_DIR
  ? path.resolve(process.env.FONTS_DIR)
  : path.join(path.dirname(SETTINGS_FILE), 'fonts');
function resolveWebRoot() {
  const candidates = [];
  if (process.env.WEB_ROOT) {
    candidates.push(path.resolve(process.env.WEB_ROOT));
  }
  candidates.push(path.join(__dirname, '../web/dist'));
  candidates.push(path.join(__dirname, '../www'));

  for (const candidate of candidates) {
    try {
      if (candidate && fs.existsSync(candidate)) {
        return candidate;
      }
    } catch (_) {
      // ignore
    }
  }

  return null;
}

const WEB_ROOT = resolveWebRoot();
const DB_FILE = process.env.DB_FILE
  ? path.resolve(process.env.DB_FILE)
  : path.join(path.dirname(SETTINGS_FILE), 'esirtv.db');

function isValidHttpUrl(value) {
  try {
    const parsed = new URL(value);
    return parsed.protocol === 'http:' || parsed.protocol === 'https:';
  } catch (_) {
    return false;
  }
}

function readSettings() {
  if (!fs.existsSync(SETTINGS_FILE)) {
    return { configUrl: '', uiFont: '' };
  }

  try {
    const raw = fs.readFileSync(SETTINGS_FILE, 'utf-8');
    const parsed = JSON.parse(raw);
    return {
      configUrl: typeof parsed.configUrl === 'string' ? parsed.configUrl.trim() : '',
      uiFont: typeof parsed.uiFont === 'string' ? parsed.uiFont.trim() : '',
    };
  } catch (error) {
    console.error('读取 settings.json 失败:', error.message);
    return { configUrl: '', uiFont: '' };
  }
}

function writeSettings(settings) {
  fs.writeFileSync(SETTINGS_FILE, `${JSON.stringify(settings, null, 2)}\n`, 'utf-8');
}

function normalizeText(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function normalizeNumber(value, fallback = 0) {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function ensureParentDir(filePath) {
  const dir = path.dirname(filePath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function ensureDir(dirPath) {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }
}

function getFontFormatByExt(ext) {
  const lower = String(ext || '').toLowerCase();
  if (lower === '.woff2') return 'woff2';
  if (lower === '.woff') return 'woff';
  if (lower === '.otf') return 'opentype';
  if (lower === '.ttf') return 'truetype';
  return '';
}

function isAllowedFontExt(ext) {
  return ['.woff2', '.woff', '.ttf', '.otf'].includes(String(ext || '').toLowerCase());
}

function listFontFiles() {
  function listFrom(dir) {
    try {
      if (!dir || !fs.existsSync(dir)) {
        return [];
      }
      const entries = fs.readdirSync(dir, { withFileTypes: true });
      return entries
        .filter((e) => e.isFile())
        .map((e) => e.name)
        .filter((name) => isAllowedFontExt(path.extname(name)));
    } catch (_) {
      return [];
    }
  }

  const builtinDir = WEB_ROOT ? path.join(WEB_ROOT, 'fonts') : '';
  const all = [...listFrom(builtinDir), ...listFrom(FONTS_DIR)];
  return Array.from(new Set(all));
}

function createDatabase() {
  ensureParentDir(DB_FILE);
  const db = new Database(DB_FILE);
  db.pragma('journal_mode = WAL');
  db.exec(`
    CREATE TABLE IF NOT EXISTS history (
      site TEXT NOT NULL,
      vod_id TEXT NOT NULL,
      title TEXT NOT NULL DEFAULT '',
      poster TEXT NOT NULL DEFAULT '',
      type_name TEXT NOT NULL DEFAULT '',
      vod_year TEXT NOT NULL DEFAULT '',
      vod_area TEXT NOT NULL DEFAULT '',
      source_index INTEGER NOT NULL DEFAULT 0,
      source_name TEXT NOT NULL DEFAULT '',
      episode_name TEXT NOT NULL DEFAULT '',
      play_url TEXT NOT NULL DEFAULT '',
      progress_sec REAL NOT NULL DEFAULT 0,
      duration_sec REAL NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (site, vod_id)
    );

    CREATE TABLE IF NOT EXISTS favorites (
      site TEXT NOT NULL,
      vod_id TEXT NOT NULL,
      title TEXT NOT NULL DEFAULT '',
      poster TEXT NOT NULL DEFAULT '',
      type_name TEXT NOT NULL DEFAULT '',
      vod_year TEXT NOT NULL DEFAULT '',
      vod_area TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (site, vod_id)
    );

    CREATE INDEX IF NOT EXISTS idx_history_updated_at ON history(updated_at DESC);
    CREATE INDEX IF NOT EXISTS idx_favorites_updated_at ON favorites(updated_at DESC);
  `);
  return db;
}

const db = createDatabase();

function mapHistoryRow(row) {
  return {
    id: `${row.site}:${row.vod_id}`,
    site: row.site,
    vodId: row.vod_id,
    title: row.title,
    poster: row.poster,
    typeName: row.type_name,
    vodYear: row.vod_year,
    vodArea: row.vod_area,
    sourceIndex: Number(row.source_index || 0),
    sourceName: row.source_name,
    episodeName: row.episode_name,
    playUrl: row.play_url,
    progressSec: Number(row.progress_sec || 0),
    durationSec: Number(row.duration_sec || 0),
    updatedAt: Number(row.updated_at || 0),
  };
}

function mapFavoriteRow(row) {
  return {
    id: `${row.site}:${row.vod_id}`,
    site: row.site,
    vodId: row.vod_id,
    title: row.title,
    poster: row.poster,
    typeName: row.type_name,
    vodYear: row.vod_year,
    vodArea: row.vod_area,
    createdAt: Number(row.created_at || 0),
    updatedAt: Number(row.updated_at || 0),
  };
}

function getConfigUrl() {
  const envUrl = (
    process.env.TVBOX_CONFIG_URL
    || process.env.ESIRTV_CONFIG_URL
    || process.env.EsirTV_CONFIG_URL
    || ''
  ).trim();
  if (envUrl) {
    return envUrl;
  }

  return readSettings().configUrl;
}

// TVBox专用请求头
const TVBOX_HEADERS = {
  'User-Agent': 'okhttp/3.12.0',
  'Accept': 'application/json, text/plain, */*',
  'Accept-Encoding': 'gzip, deflate',
  'Connection': 'keep-alive',
};

function httpRequest(url, options = {}) {
  return new Promise((resolve, reject) => {
    try {
      const urlObj = new URL(url);
      const isHttps = urlObj.protocol === 'https:';
      const client = isHttps ? https : http;

      const requestOptions = {
        hostname: urlObj.hostname,
        port: urlObj.port || (isHttps ? 443 : 80),
        path: urlObj.pathname + urlObj.search,
        method: options.method || 'GET',
        headers: { ...TVBOX_HEADERS, ...options.headers },
      };

      const req = client.request(requestOptions, (res) => {
        const contentEncoding = res.headers['content-encoding'];
        let stream = res;

        if (contentEncoding === 'gzip') {
          stream = res.pipe(zlib.createGunzip());
        } else if (contentEncoding === 'deflate') {
          stream = res.pipe(zlib.createInflate());
        }

        const chunks = [];
        stream.on('data', (chunk) => {
          chunks.push(chunk);
        });

        stream.on('end', () => {
          try {
            const data = Buffer.concat(chunks).toString('utf-8');
            const contentType = res.headers['content-type'] || '';
            const isJsonContentType = contentType.toLowerCase().includes('application/json');
            const startsWithJson = data.trim().startsWith('{') || data.trim().startsWith('[');

            if (isJsonContentType || startsWithJson) {
              resolve(JSON.parse(data));
              return;
            }

            try {
              resolve(JSON.parse(data));
            } catch (parseError) {
              reject(new Error(`响应不是有效的JSON格式。Content-Type: ${contentType}`));
            }
          } catch (error) {
            reject(new Error(`数据处理失败: ${error.message}`));
          }
        });

        stream.on('error', (error) => {
          reject(new Error(`数据流错误: ${error.message}`));
        });
      });

      req.on('error', (error) => {
        reject(error);
      });

      req.setTimeout(15000, () => {
        req.destroy();
        reject(new Error('请求超时'));
      });

      req.end();
    } catch (error) {
      reject(error);
    }
  });
}

function chooseImageReferer(urlObj) {
  const host = (urlObj.hostname || '').toLowerCase();
  if (host.endsWith('qpic.cn') || host.includes('mmbiz')) {
    return 'https://mp.weixin.qq.com/';
  }
  return `${urlObj.protocol}//${urlObj.host}/`;
}

function streamImageResponse(url, res, redirectsLeft = 3) {
  try {
    const urlObj = new URL(url);
    const isHttps = urlObj.protocol === 'https:';
    const client = isHttps ? https : http;

    const requestOptions = {
      hostname: urlObj.hostname,
      port: urlObj.port || (isHttps ? 443 : 80),
      path: urlObj.pathname + urlObj.search,
      method: 'GET',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 12; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
        'Referer': chooseImageReferer(urlObj),
      },
    };

    const req = client.request(requestOptions, (upstream) => {
      const statusCode = upstream.statusCode || 500;
      const location = upstream.headers.location;
      if (
        [301, 302, 303, 307, 308].includes(statusCode)
        && location
        && redirectsLeft > 0
      ) {
        upstream.resume();
        const nextUrl = new URL(location, urlObj).toString();
        streamImageResponse(nextUrl, res, redirectsLeft - 1);
        return;
      }

      if (statusCode >= 400) {
        upstream.resume();
        if (!res.headersSent) {
          res.status(statusCode).json({ error: `图片请求失败(${statusCode})` });
        }
        return;
      }

      res.setHeader('Cache-Control', 'public, max-age=86400');
      const contentType = upstream.headers['content-type'];
      const contentLength = upstream.headers['content-length'];
      if (contentType) {
        res.setHeader('Content-Type', contentType);
      }
      if (contentLength) {
        res.setHeader('Content-Length', contentLength);
      }

      upstream.on('error', () => {
        if (!res.headersSent) {
          res.status(502).json({ error: '图片数据流错误' });
        } else {
          res.destroy();
        }
      });
      upstream.pipe(res);
    });

    req.on('error', (error) => {
      if (!res.headersSent) {
        res.status(502).json({ error: `图片代理失败: ${error.message}` });
      } else {
        res.destroy();
      }
    });

    req.setTimeout(15000, () => {
      req.destroy(new Error('请求超时'));
    });

    req.end();
  } catch (error) {
    if (!res.headersSent) {
      res.status(400).json({ error: `无效图片链接: ${error.message}` });
    }
  }
}

let sitesCache = null;
let sitesCacheTime = 0;
const CACHE_DURATION = 5 * 60 * 1000;

function extractSitesFromConfig(config) {
  let sites = [];
  if (Array.isArray(config)) {
    if (config.length > 0 && config[0].sites) {
      sites = config[0].sites;
    }
  } else if (config && typeof config === 'object') {
    sites = config.sites || [];
  }

  return Array.isArray(sites) ? sites : [];
}

async function resolveSitesFromUrl(configUrl) {
  const config = await httpRequest(configUrl);
  const sites = extractSitesFromConfig(config);
  if (sites.length === 0) {
    throw new Error('配置可访问，但未解析到站点列表（sites 为空）');
  }
  return sites;
}

async function getSites() {
  const now = Date.now();
  if (sitesCache && (now - sitesCacheTime) < CACHE_DURATION) {
    return sitesCache;
  }

  const configUrl = getConfigUrl();
  if (!configUrl) {
    throw new Error('未配置数据源链接，请先到设置页填写');
  }

  try {
    const sites = await resolveSitesFromUrl(configUrl);
    sitesCache = sites;
    sitesCacheTime = now;
    return sites;
  } catch (error) {
    console.error('获取站点列表失败:', error.message);
    throw error;
  }
}

async function getSiteApiUrl(siteKey) {
  const sites = await getSites();
  const site = sites.find((s) => s.key === siteKey || s.name === siteKey);
  return site ? site.api : null;
}

function buildPagedResponse(data, fallbackPage) {
  const list = data.list || [];
  const page = Number(data.page || fallbackPage || 1);
  const pagecount = Number(data.pagecount || 1);
  return {
    list,
    page,
    pagecount,
    limit: Number(data.limit || 15),
    total: Number(data.total || list.length),
    hasMore: page < pagecount,
  };
}

app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.sendStatus(204);
  }

  next();
});

app.use(express.json());

app.get('/api/settings', (req, res) => {
  const settings = readSettings();
  res.json(settings);
});

app.post('/api/settings', (req, res) => {
  const hasConfigUrl = typeof req.body.configUrl === 'string';
  const configUrl = hasConfigUrl ? req.body.configUrl.trim() : '';
  const hasUiFont = typeof req.body.uiFont === 'string';
  const uiFont = hasUiFont ? req.body.uiFont.trim() : '';

  if (!hasConfigUrl && !hasUiFont) {
    return res.status(400).json({ error: 'configUrl 或 uiFont 至少提供一个' });
  }

  if (hasConfigUrl) {
    if (!configUrl) {
      return res.status(400).json({ error: 'configUrl 不能为空' });
    }
    if (!isValidHttpUrl(configUrl)) {
      return res.status(400).json({ error: 'configUrl 必须是 http/https 链接' });
    }
  }

  if (hasUiFont && uiFont) {
    const normalized = path.basename(uiFont);
    const ext = path.extname(normalized);
    if (!isAllowedFontExt(ext)) {
      return res.status(400).json({ error: 'uiFont 不支持该文件类型（仅 woff2/woff/ttf/otf）' });
    }
    const exists = listFontFiles().includes(normalized);
    if (!exists) {
      return res.status(400).json({ error: 'uiFont 指定的字体文件不存在，请先上传或放入字体目录' });
    }
  }

  try {
    const current = readSettings();
    writeSettings({
      configUrl: hasConfigUrl ? configUrl : current.configUrl,
      uiFont: hasUiFont ? uiFont : current.uiFont,
    });
    sitesCache = null;
    sitesCacheTime = 0;
    const latest = readSettings();
    res.json({ success: true, configUrl: latest.configUrl, uiFont: latest.uiFont });
  } catch (error) {
    res.status(500).json({ error: `保存配置失败: ${error.message}` });
  }
});

app.post('/api/settings/test', async (req, res) => {
  const configUrl = typeof req.body.configUrl === 'string' ? req.body.configUrl.trim() : '';

  if (!configUrl) {
    return res.status(400).json({ error: 'configUrl 不能为空', detail: '请先输入配置链接' });
  }

  if (!isValidHttpUrl(configUrl)) {
    return res.status(400).json({ error: 'configUrl 必须是 http/https 链接', detail: configUrl });
  }

  try {
    const sites = await resolveSitesFromUrl(configUrl);
    return res.json({
      success: true,
      siteCount: sites.length,
      firstSite: sites[0] ? (sites[0].name || sites[0].key || '') : '',
    });
  } catch (error) {
    return res.status(400).json({
      error: '测试失败',
      detail: error.message,
    });
  }
});

app.get('/api/history', (req, res) => {
  try {
    const site = normalizeText(req.query.site);
    const maxLimit = 200;
    const rawLimit = normalizeNumber(req.query.limit, 100);
    const limit = Math.max(1, Math.min(maxLimit, Math.floor(rawLimit)));

    const rows = site
      ? db.prepare(`
          SELECT * FROM history
          WHERE site = ?
          ORDER BY updated_at DESC
          LIMIT ?
        `).all(site, limit)
      : db.prepare(`
          SELECT * FROM history
          ORDER BY updated_at DESC
          LIMIT ?
        `).all(limit);

    res.json(rows.map(mapHistoryRow));
  } catch (error) {
    res.status(500).json({ error: `读取历史记录失败: ${error.message}` });
  }
});

app.get('/api/history/item', (req, res) => {
  try {
    const site = normalizeText(req.query.site);
    const vodId = normalizeText(req.query.vod_id);
    if (!site || !vodId) {
      return res.status(400).json({ error: 'site或vod_id参数缺失' });
    }

    const row = db.prepare(`
      SELECT * FROM history
      WHERE site = ? AND vod_id = ?
      LIMIT 1
    `).get(site, vodId);

    if (!row) {
      return res.json(null);
    }
    return res.json(mapHistoryRow(row));
  } catch (error) {
    return res.status(500).json({ error: `读取播放记录失败: ${error.message}` });
  }
});

app.post('/api/history', (req, res) => {
  try {
    const site = normalizeText(req.body.site);
    const vodId = normalizeText(req.body.vodId);
    if (!site || !vodId) {
      return res.status(400).json({ error: 'site或vodId不能为空' });
    }

    const now = Date.now();
    const payload = {
      site,
      vodId,
      title: normalizeText(req.body.title),
      poster: normalizeText(req.body.poster),
      typeName: normalizeText(req.body.typeName),
      vodYear: normalizeText(req.body.vodYear),
      vodArea: normalizeText(req.body.vodArea),
      sourceIndex: Math.max(0, Math.floor(normalizeNumber(req.body.sourceIndex, 0))),
      sourceName: normalizeText(req.body.sourceName),
      episodeName: normalizeText(req.body.episodeName),
      playUrl: normalizeText(req.body.playUrl),
      progressSec: Math.max(0, normalizeNumber(req.body.progressSec, 0)),
      durationSec: Math.max(0, normalizeNumber(req.body.durationSec, 0)),
    };

    db.prepare(`
      INSERT INTO history (
        site, vod_id, title, poster, type_name, vod_year, vod_area,
        source_index, source_name, episode_name, play_url,
        progress_sec, duration_sec, updated_at
      ) VALUES (
        @site, @vodId, @title, @poster, @typeName, @vodYear, @vodArea,
        @sourceIndex, @sourceName, @episodeName, @playUrl,
        @progressSec, @durationSec, @updatedAt
      )
      ON CONFLICT(site, vod_id) DO UPDATE SET
        title = excluded.title,
        poster = excluded.poster,
        type_name = excluded.type_name,
        vod_year = excluded.vod_year,
        vod_area = excluded.vod_area,
        source_index = excluded.source_index,
        source_name = excluded.source_name,
        episode_name = excluded.episode_name,
        play_url = excluded.play_url,
        progress_sec = excluded.progress_sec,
        duration_sec = excluded.duration_sec,
        updated_at = excluded.updated_at
    `).run({
      ...payload,
      updatedAt: now,
    });

    return res.json({ success: true, updatedAt: now });
  } catch (error) {
    return res.status(500).json({ error: `保存历史记录失败: ${error.message}` });
  }
});

app.delete('/api/history', (req, res) => {
  try {
    const site = normalizeText(req.query.site);
    const vodId = normalizeText(req.query.vod_id);
    if (!site || !vodId) {
      return res.status(400).json({ error: 'site或vod_id参数缺失' });
    }
    const result = db.prepare(`
      DELETE FROM history
      WHERE site = ? AND vod_id = ?
    `).run(site, vodId);
    return res.json({ success: true, deleted: result.changes > 0 });
  } catch (error) {
    return res.status(500).json({ error: `删除历史记录失败: ${error.message}` });
  }
});

app.get('/api/favorites', (req, res) => {
  try {
    const site = normalizeText(req.query.site);
    const rows = site
      ? db.prepare(`
          SELECT * FROM favorites
          WHERE site = ?
          ORDER BY updated_at DESC
        `).all(site)
      : db.prepare(`
          SELECT * FROM favorites
          ORDER BY updated_at DESC
        `).all();
    res.json(rows.map(mapFavoriteRow));
  } catch (error) {
    res.status(500).json({ error: `读取收藏失败: ${error.message}` });
  }
});

app.get('/api/favorites/item', (req, res) => {
  try {
    const site = normalizeText(req.query.site);
    const vodId = normalizeText(req.query.vod_id);
    if (!site || !vodId) {
      return res.status(400).json({ error: 'site或vod_id参数缺失' });
    }
    const row = db.prepare(`
      SELECT * FROM favorites
      WHERE site = ? AND vod_id = ?
      LIMIT 1
    `).get(site, vodId);
    if (!row) {
      return res.json(null);
    }
    return res.json(mapFavoriteRow(row));
  } catch (error) {
    return res.status(500).json({ error: `读取收藏状态失败: ${error.message}` });
  }
});

app.post('/api/favorites', (req, res) => {
  try {
    const site = normalizeText(req.body.site);
    const vodId = normalizeText(req.body.vodId);
    if (!site || !vodId) {
      return res.status(400).json({ error: 'site或vodId不能为空' });
    }

    const now = Date.now();
    const payload = {
      site,
      vodId,
      title: normalizeText(req.body.title),
      poster: normalizeText(req.body.poster),
      typeName: normalizeText(req.body.typeName),
      vodYear: normalizeText(req.body.vodYear),
      vodArea: normalizeText(req.body.vodArea),
    };

    db.prepare(`
      INSERT INTO favorites (
        site, vod_id, title, poster, type_name, vod_year, vod_area, created_at, updated_at
      ) VALUES (
        @site, @vodId, @title, @poster, @typeName, @vodYear, @vodArea, @createdAt, @updatedAt
      )
      ON CONFLICT(site, vod_id) DO UPDATE SET
        title = excluded.title,
        poster = excluded.poster,
        type_name = excluded.type_name,
        vod_year = excluded.vod_year,
        vod_area = excluded.vod_area,
        updated_at = excluded.updated_at
    `).run({
      ...payload,
      createdAt: now,
      updatedAt: now,
    });

    return res.json({ success: true, updatedAt: now });
  } catch (error) {
    return res.status(500).json({ error: `保存收藏失败: ${error.message}` });
  }
});

app.delete('/api/favorites', (req, res) => {
  try {
    const site = normalizeText(req.query.site);
    const vodId = normalizeText(req.query.vod_id);
    if (!site || !vodId) {
      return res.status(400).json({ error: 'site或vod_id参数缺失' });
    }

    const result = db.prepare(`
      DELETE FROM favorites
      WHERE site = ? AND vod_id = ?
    `).run(site, vodId);

    return res.json({ success: true, deleted: result.changes > 0 });
  } catch (error) {
    return res.status(500).json({ error: `取消收藏失败: ${error.message}` });
  }
});

app.get('/api/sites', async (req, res) => {
  try {
    const sites = await getSites();
    const siteList = sites.map((site) => ({
      key: site.key,
      name: site.name,
      api: site.api,
    }));
    res.json(siteList);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/site', async (req, res) => {
  try {
    const sites = await getSites();
    if (sites.length > 0) {
      res.json({ site: sites[0].key || sites[0].name });
    } else {
      res.status(404).json({ error: '未找到站点' });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/types', async (req, res) => {
  try {
    const siteKey = req.query.site;
    if (!siteKey) {
      return res.status(400).json({ error: 'site参数缺失' });
    }

    const apiUrl = await getSiteApiUrl(siteKey);
    if (!apiUrl) {
      return res.status(404).json({ error: '站点不存在' });
    }

    const listUrl = apiUrl.includes('?')
      ? `${apiUrl}&ac=list&t=0&pg=1`
      : `${apiUrl}?ac=list&t=0&pg=1`;

    const data = await httpRequest(listUrl);
    const types = (data.class || []).sort((a, b) => a.type_id - b.type_id);
    res.json(types);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/list', async (req, res) => {
  try {
    const siteKey = req.query.site;
    const typeId = parseInt(req.query.type_id || '0', 10);
    const page = parseInt(req.query.page || '1', 10);

    if (!siteKey) {
      return res.status(400).json({ error: 'site参数缺失' });
    }

    const apiUrl = await getSiteApiUrl(siteKey);
    if (!apiUrl) {
      return res.status(404).json({ error: '站点不存在' });
    }

    const listUrl = apiUrl.includes('?')
      ? `${apiUrl}&ac=list&t=${typeId}&pg=${page}`
      : `${apiUrl}?ac=list&t=${typeId}&pg=${page}`;

    const data = await httpRequest(listUrl);
    res.json(buildPagedResponse(data, page));
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/search', async (req, res) => {
  try {
    const siteKey = req.query.site;
    const keyword = (req.query.wd || '').trim();
    const page = parseInt(req.query.page || '1', 10);

    if (!siteKey) {
      return res.status(400).json({ error: 'site参数缺失' });
    }
    if (!keyword) {
      return res.status(400).json({ error: 'wd参数缺失' });
    }

    const apiUrl = await getSiteApiUrl(siteKey);
    if (!apiUrl) {
      return res.status(404).json({ error: '站点不存在' });
    }

    const encodedKeyword = encodeURIComponent(keyword);
    const searchUrl = apiUrl.includes('?')
      ? `${apiUrl}&ac=list&wd=${encodedKeyword}&pg=${page}`
      : `${apiUrl}?ac=list&wd=${encodedKeyword}&pg=${page}`;

    const data = await httpRequest(searchUrl);
    res.json(buildPagedResponse(data, page));
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/detail', async (req, res) => {
  try {
    const siteKey = req.query.site;
    const vodId = req.query.vod_id;

    if (!siteKey || !vodId) {
      return res.status(400).json({ error: 'site或vod_id参数缺失' });
    }

    const apiUrl = await getSiteApiUrl(siteKey);
    if (!apiUrl) {
      return res.status(404).json({ error: '站点不存在' });
    }

    const detailUrl = apiUrl.includes('?')
      ? `${apiUrl}&ac=detail&ids=${vodId}`
      : `${apiUrl}?ac=detail&ids=${vodId}`;

    const data = await httpRequest(detailUrl);
    const detail = data.list && data.list.length > 0 ? data.list[0] : null;

    if (!detail) {
      return res.status(404).json({ error: '视频不存在' });
    }

    res.json(detail);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/image', (req, res) => {
  const imageUrl = typeof req.query.url === 'string' ? req.query.url.trim() : '';
  if (!imageUrl) {
    return res.status(400).json({ error: 'url参数缺失' });
  }
  if (!isValidHttpUrl(imageUrl)) {
    return res.status(400).json({ error: 'url必须是 http/https 链接' });
  }

  streamImageResponse(imageUrl, res);
});

app.get('/api/fonts', (req, res) => {
  const files = listFontFiles();
  res.json({
    dir: FONTS_DIR,
    files: files.map((file) => ({
      file,
      family: path.basename(file, path.extname(file)),
      ext: path.extname(file),
      format: getFontFormatByExt(path.extname(file)),
      url: `/fonts/${encodeURIComponent(file)}`,
    })),
  });
});

app.post(
  '/api/fonts/upload',
  express.raw({ type: 'application/octet-stream', limit: '30mb' }),
  (req, res) => {
    try {
      const nameRaw = typeof req.query.name === 'string' ? req.query.name : '';
      const safeName = path.basename(nameRaw || '');
      if (!safeName) {
        return res.status(400).json({ error: 'name 参数缺失' });
      }

      const ext = path.extname(safeName);
      if (!isAllowedFontExt(ext)) {
        return res.status(400).json({ error: '仅支持 woff2/woff/ttf/otf 字体文件' });
      }

      const body = req.body;
      if (!body || !(body instanceof Buffer) || body.length === 0) {
        return res.status(400).json({ error: '未读取到字体文件内容' });
      }

      ensureDir(FONTS_DIR);
      const targetPath = path.join(FONTS_DIR, safeName);
      fs.writeFileSync(targetPath, body);

      return res.json({
        success: true,
        file: safeName,
        family: path.basename(safeName, ext),
        url: `/fonts/${encodeURIComponent(safeName)}`,
      });
    } catch (error) {
      return res.status(500).json({ error: `上传字体失败: ${error.message}` });
    }
  },
);

ensureDir(FONTS_DIR);
if (WEB_ROOT) {
  app.use('/fonts', express.static(path.join(WEB_ROOT, 'fonts'), { fallthrough: true }));
}
app.use('/fonts', express.static(FONTS_DIR));

if (WEB_ROOT) {
  app.use(express.static(WEB_ROOT));

  // SPA fallback: keep old multi-page URLs working, and allow Vue Router history mode.
  app.get('*', (req, res, next) => {
    if (req.method !== 'GET') {
      return next();
    }
    if (req.path === '/api' || req.path.startsWith('/api/')) {
      return next();
    }

    const ext = path.extname(req.path).toLowerCase();
    if (ext && ext !== '.html') {
      return next();
    }

    const indexPath = path.join(WEB_ROOT, 'index.html');
    if (!fs.existsSync(indexPath)) {
      return next();
    }
    return res.sendFile(indexPath);
  });
} else {
  console.warn('未找到前端静态资源目录（web/dist 或 www 不存在），仅提供 API 服务。');
}

app.listen(PORT, () => {
  console.log(`服务器运行在 http://localhost:${PORT}`);
  const current = getConfigUrl();
  if (current) {
    console.log(`当前数据源: ${current}`);
  } else {
    console.log('当前尚未配置数据源，请在设置页填写');
  }
});

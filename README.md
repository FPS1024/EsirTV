<p align="center">
  <a href="./README.md"><strong>English</strong></a> ·
  <a href="./README.zh-CN.md"><strong>简体中文</strong></a>
</p>

# EsirTV

A Web poster-wall + player built on **TVBox config**, with one-command Docker deployment.

## Features

- Poster wall: categories/search, history, favorites
- Playback: ArtPlayer + hls.js (HLS `.m3u8` / common MP4), speed control/hotkeys/PiP
- Settings: TVBox source, font upload & selection, language switch (`zh-CN` / `en-US` / `ug-CN`)
- Persistence: SQLite (history/favorites) + settings.json (config/font/lang)

## Tech Stack

- Frontend: Vue 3 + Vite + vue-router + vue-i18n
- Player: ArtPlayer + hls.js
- Backend: Node.js + Express + better-sqlite3
- Deploy: Docker / Docker Compose

## Quick Start (Docker)

```bash
docker compose up -d --build
```

Open:

- Home: `http://localhost:8080/`
- Settings: `http://localhost:8080/settings`

First run: open Settings and fill in a **TVBox config URL** (a JSON that contains a `sites` list).

Stop:

```bash
docker compose down
```

## Configuration & Persistence

By default, Compose uses a named volume `esirtv-data`:

- `/data/settings.json`: app settings (`configUrl`, `uiFont`, `uiLang`)
- `/data/esirtv.db`: history & favorites (SQLite)
- `/data/fonts/*`: uploaded UI font files

### Environment Variables

- `PORT`: server port (default `8080`)
- `SETTINGS_FILE`: settings file path (default `/data/settings.json`)
- `DB_FILE`: SQLite DB path (default `/data/esirtv.db`)
- `TVBOX_CONFIG_URL`: inject TVBox config URL (overrides `settings.json`)
- `ESIRTV_CONFIG_URL`: alias of `TVBOX_CONFIG_URL`
- `FONTS_DIR`: font storage dir (default `/data/fonts`)
- `WEB_ROOT`: override static web root (optional)

## Local Development

Backend:

```bash
node app/server/server.js
```

Frontend (Vite at `http://localhost:5173`, proxies `/api` to `:8080`):

```bash
npm --prefix app/web install
npm --prefix app/web run dev
```

## Routes

- `/`: poster wall
- `/settings`: settings
- `/detail/:site/:vodId`: details & playback
- Legacy routes still work: `/settings.html`, `/detail.html?site=...&vod_id=...`

## Notes

- This project does **not** include or host any video content. It only consumes third-party TVBox-compatible sources configured by the user.
- Browser decoding capability depends on the browser/device. For unsupported codecs/containers, consider server-side remux/transcode.

## Docs

- Docker guide: `DOCKER.md`

## License

MIT License. See `LICENSE`.

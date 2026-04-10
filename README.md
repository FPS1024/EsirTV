# EsirTV

一个基于 **TVBox 配置** 的 Web 影视海报墙 + 播放器。

- 前端：Vue 3 + Vite（海报墙 / 详情播放 / 设置）
- 播放器：ArtPlayer + hls.js（支持 `.m3u8`，倍速/快捷键等）
- 后端：Node.js + Express（聚合站点、代理图片、历史记录/收藏 SQLite 持久化）
- 部署：Docker Compose 一键启动

## 快速开始（Docker）

```bash
docker compose up -d --build
```

访问：

- 首页：`http://localhost:8080/`
- 设置：`http://localhost:8080/settings`

首次使用请先到设置页填写 `TVBox` 配置链接（能解析出 `sites` 列表的 JSON）。

停止：

```bash
docker compose down
```

## 配置与持久化

默认使用命名卷 `esirtv-data` 持久化：

- `/data/settings.json`：配置（主要是 `configUrl`）
- `/data/esirtv.db`：历史记录、收藏（SQLite）

可选环境变量（见 `docker-compose.yml` / `DOCKER.md`）：

- `PORT`：服务端口（默认 `8080`）
- `SETTINGS_FILE`：配置文件路径（默认 `/data/settings.json`）
- `DB_FILE`：数据库路径（默认 `/data/esirtv.db`）
- `TVBOX_CONFIG_URL`：直接注入数据源链接（优先级高于 `settings.json`）
- `ESIRTV_CONFIG_URL`：同 `TVBOX_CONFIG_URL`（兼容别名）

## 前端开发（可选）

后端（本机）：

```bash
node app/server/server.js
```

前端（Vite，默认 `http://localhost:5173`，已代理 `/api` 到 `:8080`）：

```bash
npm --prefix app/web install
npm --prefix app/web run dev
```

## 路由说明

- `/`：海报墙
- `/settings`：设置页
- `/detail/:site/:vodId`：详情播放页
- 兼容旧地址：`/settings.html`、`/detail.html?site=...&vod_id=...`

## 文档

- Docker 详细说明：`DOCKER.md`

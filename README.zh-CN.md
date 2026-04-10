<p align="center">
  <a href="./README.md"><strong>English</strong></a> ·
  <a href="./README.zh-CN.md"><strong>简体中文</strong></a>
</p>

# EsirTV

一个基于 **TVBox 配置** 的 Web 影视海报墙 + 播放器（Docker 一键部署）。

## 功能特性

- 海报墙：分类/搜索、历史记录、收藏
- 播放页：ArtPlayer + hls.js（HLS `.m3u8` / 常见 MP4），倍速/快捷键/画中画
- 设置页：TVBox 数据源配置、字体上传与选择、语言切换（`zh-CN` / `en-US` / `ug-CN`）
- 持久化：SQLite（历史记录/收藏）+ `settings.json`（配置/字体/语言）

## 技术栈

- 前端：Vue 3 + Vite + vue-router + vue-i18n
- 播放器：ArtPlayer + hls.js
- 后端：Node.js + Express + better-sqlite3
- 部署：Docker / Docker Compose

## 快速开始（Docker）

```bash
docker compose up -d --build
```

访问：

- 首页：`http://localhost:8080/`
- 设置：`http://localhost:8080/settings`

首次使用：打开设置页填写 **TVBox 配置链接**（能解析出 `sites` 列表的 JSON）。

停止：

```bash
docker compose down
```

## 配置与持久化

默认使用命名卷 `esirtv-data`：

- `/data/settings.json`：应用设置（`configUrl` / `uiFont` / `uiLang`）
- `/data/esirtv.db`：历史记录、收藏（SQLite）
- `/data/fonts/*`：上传的 UI 字体文件

### 环境变量

- `PORT`：服务端口（默认 `8080`）
- `SETTINGS_FILE`：配置文件路径（默认 `/data/settings.json`）
- `DB_FILE`：SQLite 数据库路径（默认 `/data/esirtv.db`）
- `TVBOX_CONFIG_URL`：直接注入数据源链接（优先级高于 `settings.json`）
- `ESIRTV_CONFIG_URL`：同 `TVBOX_CONFIG_URL`（兼容别名）
- `FONTS_DIR`：字体存储目录（默认 `/data/fonts`）
- `WEB_ROOT`：覆盖静态资源根目录（可选）

## 本地开发

后端：

```bash
node app/server/server.js
```

前端（Vite 默认 `http://localhost:5173`，已代理 `/api` 到 `:8080`）：

```bash
npm --prefix app/web install
npm --prefix app/web run dev
```

## 路由说明

- `/`：海报墙
- `/settings`：设置页
- `/detail/:site/:vodId`：详情播放页
- 兼容旧地址：`/settings.html`、`/detail.html?site=...&vod_id=...`

## 说明

- 本项目不提供、不托管任何影视内容，仅消费用户配置的第三方 TVBox 数据源。
- 浏览器解码能力取决于浏览器/设备；如遇到不支持的编码/封装，可考虑服务端转封装/转码。

## 文档

- Docker 说明：`DOCKER.md`

## License

MIT License，见 `LICENSE`。

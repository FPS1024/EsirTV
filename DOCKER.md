# EsirTV Docker 使用说明

## 启动
在项目根目录执行：

```bash
docker compose up -d --build
```

默认访问地址：

- 首页: `http://localhost:8080/`
- 设置页: `http://localhost:8080/settings`（旧地址 `settings.html` 仍可用）

## 停止

```bash
docker compose down
```

## 持久化
`docker-compose.yml` 已内置命名卷 `esirtv-data`，用于保存配置文件：

- 容器内路径: `/data/settings.json`
- 容器内路径: `/data/esirtv.db`（历史记录、收藏）

## 可选环境变量
- `PORT`: 服务端口（默认 `8080`）
- `SETTINGS_FILE`: 配置文件路径（默认 `/data/settings.json`）
- `DB_FILE`: SQLite 数据库文件（默认 `/data/esirtv.db`）
- `TVBOX_CONFIG_URL`: 直接指定数据源链接（设置后会覆盖 `settings.json` 中的链接）
- `ESIRTV_CONFIG_URL`: 同 `TVBOX_CONFIG_URL`（兼容别名）

## 前端开发（可选）
后端：

```bash
node app/server/server.js
```

前端（Vite）：

```bash
npm --prefix app/web install
npm --prefix app/web run dev
```

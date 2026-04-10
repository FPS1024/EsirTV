<template>
  <main class="max-w-3xl mx-auto p-4 md:p-8">
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-2xl md:text-3xl font-bold">数据源设置</h1>
      <router-link to="/" class="bg-slate-800 hover:bg-slate-700 px-3 py-2 rounded-lg text-sm">
        <i class="fa-solid fa-house"></i>
        返回首页
      </router-link>
    </div>

    <section class="glass-effect rounded-xl p-5 md:p-6 border border-slate-800">
      <label for="configUrl" class="block text-sm text-slate-300 mb-2">TVBox 配置链接</label>
      <input
        id="configUrl"
        v-model.trim="configUrl"
        type="text"
        placeholder="https://example.com/tvbox.json"
        class="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 mb-3"
      />
      <p class="text-slate-400 text-sm mb-4">保存后首页会从该链接拉取站点列表。</p>

      <div class="flex items-center gap-3 flex-wrap">
        <button @click="save(false)" class="bg-blue-600 hover:bg-blue-500 px-4 py-2 rounded-lg">保存配置</button>
        <button @click="save(true)" class="bg-slate-800 hover:bg-slate-700 px-4 py-2 rounded-lg">保存并验证</button>
        <button @click="testOnly" class="bg-slate-800 hover:bg-slate-700 px-4 py-2 rounded-lg">仅测试链接</button>
      </div>

      <div v-if="msg.text" class="mt-4 rounded-lg px-4 py-3 text-sm border" :class="msgClass">
        {{ msg.text }}
      </div>
      <pre
        v-if="msg.detail"
        class="mt-3 rounded-lg bg-slate-900 border border-slate-700 px-4 py-3 text-xs text-slate-300 whitespace-pre-wrap break-all"
      >{{ msg.detail }}</pre>
    </section>

    <section class="glass-effect rounded-xl p-5 md:p-6 border border-slate-800 mt-6">
      <h2 class="text-lg font-semibold mb-4">字体设置</h2>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label for="fontSelect" class="block text-sm text-slate-300 mb-2">当前字体</label>
          <select
            id="fontSelect"
            v-model="uiFont"
            class="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2"
          >
            <option value="">默认（系统字体）</option>
            <option v-for="f in fonts" :key="f.file" :value="f.file">{{ f.family }}（{{ f.file }}）</option>
          </select>
          <p class="text-slate-400 text-sm mt-2">
            字体文件来源：容器内 `/data/fonts`（上传后自动持久化）。也支持随前端打包的内置字体。
          </p>
          <button @click="saveFontOnly" class="mt-3 bg-slate-800 hover:bg-slate-700 px-4 py-2 rounded-lg">
            保存字体选择
          </button>
        </div>

        <div>
          <label class="block text-sm text-slate-300 mb-2">上传字体文件</label>
          <input
            ref="fontFileInput"
            type="file"
            accept=".woff2,.woff,.ttf,.otf"
            class="block w-full text-sm text-slate-300 file:mr-3 file:py-2 file:px-3 file:rounded-lg file:border-0 file:bg-slate-800 file:text-slate-200 hover:file:bg-slate-700"
            @change="onFontFileSelected"
          />
          <p class="text-slate-400 text-sm mt-2">支持：woff2 / woff / ttf / otf。</p>
        </div>
      </div>
    </section>
  </main>
</template>

<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { EsirtvApi } from '../lib/api.js';

const configUrl = ref('');
const uiFont = ref('');
const fonts = ref([]);
const fontFileInput = ref(null);
const msg = reactive({ text: '', type: 'info', detail: '' });

const msgClass = computed(() => {
  if (msg.type === 'error') {
    return 'bg-rose-950/40 border-rose-600/40 text-rose-200';
  }
  return 'bg-emerald-950/40 border-emerald-600/40 text-emerald-200';
});

function setMessage(text, type = 'info', detail = '') {
  msg.text = text;
  msg.type = type;
  msg.detail = detail || '';
}

async function loadSettings() {
  try {
    const data = await EsirtvApi.getSettings();
    configUrl.value = data.configUrl || '';
    uiFont.value = data.uiFont || '';
  } catch (error) {
    setMessage(error?.message || '读取配置失败', 'error');
  }
}

async function loadFonts() {
  try {
    const data = await EsirtvApi.listFonts();
    fonts.value = Array.isArray(data.files) ? data.files : [];
  } catch (error) {
    setMessage(error?.message || '读取字体列表失败', 'error');
  }
}

async function save(verify = false) {
  const value = (configUrl.value || '').trim();
  if (!value) {
    setMessage('请输入配置链接。', 'error');
    return;
  }

  try {
    await EsirtvApi.saveSettings({ configUrl: value, uiFont: uiFont.value || '' });
    if (!verify) {
      setMessage('保存成功。');
      return;
    }
    const sitesData = await EsirtvApi.getSites();
    setMessage(`保存并验证成功，站点数量：${sitesData.length}`);
  } catch (error) {
    setMessage('保存失败', 'error', error?.message || '未知错误');
  }
}

async function saveFontOnly() {
  try {
    await EsirtvApi.saveSettings({ uiFont: uiFont.value || '' });
    setMessage('字体已保存。');
  } catch (error) {
    setMessage('保存失败', 'error', error?.message || '未知错误');
  }
}

async function testOnly() {
  const value = (configUrl.value || '').trim();
  if (!value) {
    setMessage('测试失败', 'error', '请输入配置链接后再测试。');
    return;
  }

  try {
    const data = await EsirtvApi.testSettings(value);
    const firstSiteMsg = data.firstSite ? `，首站：${data.firstSite}` : '';
    setMessage(`测试成功，站点数量：${data.siteCount}${firstSiteMsg}`);
  } catch (error) {
    setMessage('测试失败', 'error', error?.message || '未知错误');
  }
}

async function onFontFileSelected(event) {
  const file = event && event.target && event.target.files ? event.target.files[0] : null;
  if (!file) {
    return;
  }

  try {
    const result = await EsirtvApi.uploadFont(file, file.name);
    await loadFonts();
    if (result && result.file) {
      uiFont.value = result.file;
      setMessage(`上传成功：${result.file}`);
    } else {
      setMessage('上传成功。');
    }
  } catch (error) {
    setMessage('上传失败', 'error', error?.message || '未知错误');
  } finally {
    if (fontFileInput.value) {
      fontFileInput.value.value = '';
    }
  }
}

onMounted(async () => {
  await loadSettings();
  await loadFonts();
});
</script>

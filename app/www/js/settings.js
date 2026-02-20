function setMessage(text, type = 'info', detail = '') {
  const msg = document.getElementById('msg');
  const detailMsg = document.getElementById('detailMsg');
  msg.textContent = text;
  msg.classList.remove('hidden', 'bg-emerald-950/40', 'border-emerald-600/40', 'text-emerald-200', 'bg-rose-950/40', 'border-rose-600/40', 'text-rose-200');
  detailMsg.classList.add('hidden');
  detailMsg.textContent = '';

  if (type === 'error') {
    msg.classList.add('bg-rose-950/40', 'border', 'border-rose-600/40', 'text-rose-200');
    if (detail) {
      detailMsg.textContent = detail;
      detailMsg.classList.remove('hidden');
    }
    return;
  }

  msg.classList.add('bg-emerald-950/40', 'border', 'border-emerald-600/40', 'text-emerald-200');
}

async function loadSettings() {
  try {
    const data = await window.EsirtvApi.getSettings();
    document.getElementById('configUrl').value = data.configUrl || '';
  } catch (error) {
    setMessage(error.message || '读取配置失败', 'error');
  }
}

async function saveSettings(verify = false) {
  const configUrl = document.getElementById('configUrl').value.trim();
  if (!configUrl) {
    setMessage('请输入配置链接。', 'error');
    return;
  }

  try {
    await window.EsirtvApi.saveSettings(configUrl);

    if (!verify) {
      setMessage('保存成功。');
      return;
    }

    const sitesData = await window.EsirtvApi.getSites();
    setMessage(`保存并验证成功，站点数量：${sitesData.length}`);
  } catch (error) {
    setMessage('保存失败', 'error', error.message || '未知错误');
  }
}

async function testSettingsOnly() {
  const configUrl = document.getElementById('configUrl').value.trim();
  if (!configUrl) {
    setMessage('测试失败', 'error', '请输入配置链接后再测试。');
    return;
  }

  try {
    const data = await window.EsirtvApi.testSettings(configUrl);
    const firstSiteMsg = data.firstSite ? `，首站：${data.firstSite}` : '';
    setMessage(`测试成功，站点数量：${data.siteCount}${firstSiteMsg}`);
  } catch (error) {
    setMessage('测试失败', 'error', error.message || '未知错误');
  }
}

document.getElementById('saveBtn').addEventListener('click', () => saveSettings(false));
document.getElementById('verifyBtn').addEventListener('click', () => saveSettings(true));
document.getElementById('testBtn').addEventListener('click', () => testSettingsOnly());

loadSettings();

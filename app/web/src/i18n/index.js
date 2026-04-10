import zhCN from '../locales/zh-CN.json';
import enUS from '../locales/en-US.json';
import ugCN from '../locales/ug-CN.json';

export const SUPPORTED_LOCALES = ['zh-CN', 'en-US', 'ug-CN'];

export const messages = {
  'zh-CN': zhCN,
  'en-US': enUS,
  'ug-CN': ugCN
};

export function normalizeLocale(locale) {
  const value = String(locale || '').trim();
  if (SUPPORTED_LOCALES.includes(value)) {
    return value;
  }
  return 'zh-CN';
}


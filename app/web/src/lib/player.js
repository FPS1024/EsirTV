import Artplayer from 'artplayer';
import Hls from 'hls.js';

function isHlsUrl(url) {
  const lower = (url || '').toLowerCase();
  return lower.includes('.m3u8') || lower.includes('m3u');
}

function attachResumeOnce(videoEl, resumeSec) {
  if (!videoEl || !resumeSec || resumeSec <= 0) {
    return;
  }

  const applyResume = () => {
    const duration = Number(videoEl.duration || 0);
    const target = duration > 1 ? Math.min(resumeSec, Math.max(duration - 1, 0)) : resumeSec;
    if (target > 0) {
      videoEl.currentTime = target;
    }
  };

  if (videoEl.readyState >= 1) {
    applyResume();
    return;
  }

  videoEl.addEventListener('loadedmetadata', applyResume, { once: true });
}

function parseEpisodeGroup(rawGroup) {
  if (!rawGroup) {
    return [];
  }

  const episodes = rawGroup
    .split('#')
    .map((raw) => raw.split('$'))
    .filter((pair) => pair.length === 2)
    .map(([name, url]) => ({ name: name.trim(), url: url.trim() }))
    .filter((item) => item.url.startsWith('http'));

  if (episodes.length > 0) {
    return episodes;
  }

  const trimmed = rawGroup.trim();
  if (trimmed.startsWith('http')) {
    return [{ name: '正片', url: trimmed }];
  }

  return [];
}

export function parseSources(vodPlayFrom, vodPlayUrl) {
  const fromParts = String(vodPlayFrom || '默认线路')
    .split('$$$')
    .map((item) => item.trim())
    .filter(Boolean);
  const urlParts = String(vodPlayUrl || '')
    .split('$$$')
    .map((item) => item.trim());
  const sourceCount = Math.max(fromParts.length, urlParts.length);
  const sources = [];

  for (let i = 0; i < sourceCount; i += 1) {
    const name = fromParts[i] || `线路${i + 1}`;
    const episodes = parseEpisodeGroup(urlParts[i] || '');
    if (episodes.length > 0) {
      sources.push({ name, episodes, index: i });
    }
  }

  return sources;
}

export function createVideoPlayer(containerEl, onFatalError) {
  let art = null;

  function ensureArt() {
    if (art) {
      return art;
    }

    art = new Artplayer({
      container: containerEl,
      url: '',
      autoplay: false,
      autoSize: true,
      setting: true,
      hotkey: true,
      pip: true,
      playbackRate: true,
      fullscreen: true,
      fullscreenWeb: true,
      fastForward: true,
      // Keep native controls off; ArtPlayer renders its own UI.
      controls: [],
      customType: {
        m3u8: (video, url, artInstance) => {
          if (artInstance.__hls) {
            artInstance.__hls.destroy();
            artInstance.__hls = null;
          }

          if (Hls.isSupported()) {
            const hls = new Hls();
            artInstance.__hls = hls;
            hls.loadSource(url);
            hls.attachMedia(video);
            hls.on(Hls.Events.ERROR, (_event, data) => {
              if (data && data.fatal) {
                try {
                  hls.destroy();
                } catch (_) {
                  // ignore
                }
                artInstance.__hls = null;
                video.src = url;
                if (typeof onFatalError === 'function') {
                  onFatalError('HLS 播放异常，已回退原生播放器');
                }
              }
            });
          } else {
            video.src = url;
          }
        },
      },
    });

    return art;
  }

  function destroy() {
    if (!art) {
      return;
    }
    try {
      if (art.__hls) {
        art.__hls.destroy();
        art.__hls = null;
      }
    } catch (_) {
      // ignore
    }
    art.destroy(false);
    art = null;
  }

  async function play(url, resumeSec = 0) {
    const instance = ensureArt();
    if (!url) {
      return;
    }

    const wantsHls = isHlsUrl(url);
    instance.type = wantsHls ? 'm3u8' : '';

    if (instance.url !== url) {
      await instance.switchUrl(url);
    }

    attachResumeOnce(instance.video, resumeSec);
    instance.play().catch(() => {});
  }

  function getVideoElement() {
    return ensureArt().video;
  }

  return {
    play,
    destroy,
    getVideoElement,
  };
}

(function attachEsirtvPlayer(global) {
  function isHlsUrl(url) {
    const lower = (url || '').toLowerCase();
    return lower.includes('.m3u8') || lower.includes('m3u');
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

  function parseSources(vodPlayFrom, vodPlayUrl) {
    const fromParts = String(vodPlayFrom || '默认线路').split('$$$').map((item) => item.trim()).filter(Boolean);
    const urlParts = String(vodPlayUrl || '').split('$$$').map((item) => item.trim());
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

  function createVideoPlayer(videoEl, onFatalError) {
    let hls = null;

    function destroy() {
      if (hls) {
        hls.destroy();
        hls = null;
      }
    }

    function attachResumeOnce(resumeSec) {
      if (!resumeSec || resumeSec <= 0) {
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

    function play(url, resumeSec = 0) {
      destroy();

      if (isHlsUrl(url) && global.Hls && global.Hls.isSupported()) {
        hls = new global.Hls();
        hls.loadSource(url);
        hls.attachMedia(videoEl);
        hls.on(global.Hls.Events.MANIFEST_PARSED, () => {
          attachResumeOnce(resumeSec);
          videoEl.play().catch(() => {});
        });
        hls.on(global.Hls.Events.ERROR, (_event, data) => {
          if (data && data.fatal) {
            destroy();
            videoEl.src = url;
            attachResumeOnce(resumeSec);
            videoEl.play().catch(() => {});
            if (typeof onFatalError === 'function') {
              onFatalError('HLS 播放异常，已回退原生播放器');
            }
          }
        });
        return;
      }

      videoEl.src = url;
      attachResumeOnce(resumeSec);
      videoEl.play().catch(() => {});
    }

    return {
      play,
      destroy,
    };
  }

  global.EsirtvPlayer = {
    parseSources,
    createVideoPlayer,
  };
}(window));

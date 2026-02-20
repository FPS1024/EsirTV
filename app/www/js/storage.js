(function attachEsirTvStorage(global) {
  function getJSON(key, fallbackValue) {
    try {
      const raw = global.localStorage.getItem(key);
      if (!raw) {
        return fallbackValue;
      }
      return JSON.parse(raw);
    } catch (_) {
      return fallbackValue;
    }
  }

  function setJSON(key, value) {
    try {
      global.localStorage.setItem(key, JSON.stringify(value));
      return true;
    } catch (_) {
      return false;
    }
  }

  function remove(key) {
    try {
      global.localStorage.removeItem(key);
      return true;
    } catch (_) {
      return false;
    }
  }

  global.EsirtvStorage = {
    getJSON,
    setJSON,
    remove,
  };
}(window));

const { createApp } = Vue;
const HOME_STATE_KEY = 'esirtv.homeState';
const HOME_SAVE_DELAY_MS = 200;
const HISTORY_TYPE_ID = -1;
const FAVORITES_TYPE_ID = -2;

createApp({
  data() {
    return {
      HISTORY_TYPE_ID,
      FAVORITES_TYPE_ID,
      sites: [],
      site: '',
      types: [],
      currentType: HISTORY_TYPE_ID,
      movies: [],
      keyword: '',
      activeKeyword: '',
      searchMode: false,
      currentPage: 1,
      pagecount: 1,
      hasMore: false,
      isLoading: false,
      errorMsg: '',
      autoLoadSupported: typeof window.IntersectionObserver !== 'undefined',
      loadMoreObserver: null,
      saveTimer: null,
    };
  },
  computed: {
    currentTypeName() {
      if (this.searchMode) {
        return `搜索结果：${this.activeKeyword}`;
      }
      if (this.currentType === HISTORY_TYPE_ID) {
        return '历史记录';
      }
      if (this.currentType === FAVORITES_TYPE_ID) {
        return '我的收藏';
      }
      const target = this.types.find((item) => Number(item.type_id) === Number(this.currentType));
      return target ? `${target.type_name} 精选` : '精选';
    },
  },
  methods: {
    loadHomeState() {
      return window.EsirtvStorage.getJSON(HOME_STATE_KEY, {
        site: '',
        typeId: HISTORY_TYPE_ID,
        keyword: '',
      });
    },
    saveHomeState(immediate = false) {
      const persist = () => {
        window.EsirtvStorage.setJSON(HOME_STATE_KEY, {
          site: this.site || '',
          typeId: Number(this.currentType),
          keyword: this.keyword || '',
          activeKeyword: this.searchMode ? this.activeKeyword : '',
          searchMode: Boolean(this.searchMode),
          currentPage: Number(this.currentPage || 1),
          pagecount: Number(this.pagecount || 1),
          hasMore: Boolean(this.hasMore),
          movies: Array.isArray(this.movies) ? this.movies : [],
          scrollY: Math.max(0, Number(window.scrollY || 0)),
          updatedAt: Date.now(),
        });
      };

      if (immediate) {
        if (this.saveTimer) {
          clearTimeout(this.saveTimer);
          this.saveTimer = null;
        }
        persist();
        return;
      }

      if (this.saveTimer) {
        clearTimeout(this.saveTimer);
      }
      this.saveTimer = setTimeout(() => {
        this.saveTimer = null;
        persist();
      }, HOME_SAVE_DELAY_MS);
    },
    canRestoreHomeState(saved, expectedSite) {
      if (!saved || typeof saved !== 'object') {
        return false;
      }
      if (!expectedSite || saved.site !== expectedSite) {
        return false;
      }
      if (!Array.isArray(saved.movies) || saved.movies.length === 0) {
        return false;
      }
      if (saved.searchMode && !saved.activeKeyword) {
        return false;
      }
      return true;
    },
    restoreHomeState(saved) {
      this.currentType = Number(saved.typeId);
      this.keyword = saved.keyword || '';
      this.activeKeyword = saved.activeKeyword || '';
      this.searchMode = Boolean(saved.searchMode);
      this.currentPage = Number(saved.currentPage || 1);
      this.pagecount = Number(saved.pagecount || 1);
      this.hasMore = Boolean(saved.hasMore);
      this.movies = this.remapPosterIfNeeded(saved.movies);
      this.$nextTick(() => {
        window.scrollTo({ top: Math.max(0, Number(saved.scrollY || 0)), behavior: 'auto' });
      });
    },
    setupAutoLoadObserver() {
      if (!this.autoLoadSupported || this.loadMoreObserver) {
        return;
      }
      const target = this.$refs.loadMoreSentinel;
      if (!target) {
        return;
      }
      this.loadMoreObserver = new window.IntersectionObserver((entries) => {
        const visible = entries.some((entry) => entry.isIntersecting);
        if (visible) {
          this.triggerAutoLoadIfNeeded();
        }
      }, {
        root: null,
        rootMargin: '300px 0px',
        threshold: 0.01,
      });
      this.loadMoreObserver.observe(target);
    },
    triggerAutoLoadIfNeeded() {
      if (!this.autoLoadSupported || this.isLoading || !this.hasMore) {
        return;
      }
      if (this.currentType === HISTORY_TYPE_ID || this.currentType === FAVORITES_TYPE_ID) {
        return;
      }
      const target = this.$refs.loadMoreSentinel;
      if (!target) {
        return;
      }
      const rect = target.getBoundingClientRect();
      if (rect.top <= (window.innerHeight + 300)) {
        this.loadMore();
      }
    },
    tearDownAutoLoadObserver() {
      if (this.loadMoreObserver) {
        this.loadMoreObserver.disconnect();
        this.loadMoreObserver = null;
      }
    },
    onScrollSave() {
      this.saveHomeState(false);
    },
    remapPosterIfNeeded(list) {
      return (list || []).map((item) => {
        if (!item || typeof item !== 'object') {
          return item;
        }
        const rawPoster = item.vod_pic || item.poster || '';
        return {
          ...item,
          poster: rawPoster ? window.EsirtvApi.getPosterUrl(rawPoster) : '',
        };
      });
    },
    saveAndResetListState() {
      window.EsirtvStorage.setJSON(HOME_STATE_KEY, {
        site: this.site || '',
        typeId: HISTORY_TYPE_ID,
        keyword: '',
        activeKeyword: '',
        searchMode: false,
        currentPage: 1,
        pagecount: 1,
        hasMore: false,
        movies: [],
        scrollY: 0,
        updatedAt: Date.now(),
      });
    },
    mapMovies(list) {
      return (list || []).map((item) => ({
        ...item,
        id: item.vod_id,
        title: item.vod_name,
        poster: window.EsirtvApi.getPosterUrl(item.vod_pic),
      }));
    },
    mapRecordItems(list) {
      return (list || []).map((item) => ({
        id: `${item.site}:${item.vodId}`,
        vod_id: item.vodId,
        vod_name: item.title,
        vod_pic: item.poster || '',
        title: item.title,
        poster: item.poster ? window.EsirtvApi.getPosterUrl(item.poster) : '',
        site: item.site,
        recordUpdatedAt: item.updatedAt || 0,
      }));
    },
    async fetchSites() {
      const data = await window.EsirtvApi.getSites();
      this.sites = data;
      if (!this.site && data.length > 0) {
        this.site = data[0].key || data[0].name;
      }
    },
    async fetchTypes() {
      this.types = await window.EsirtvApi.getTypes(this.site);
    },
    async fetchMovies(page = 1, append = false) {
      this.isLoading = true;
      try {
        const data = await window.EsirtvApi.getList(this.site, this.currentType, page);
        const mapped = this.mapMovies(data.list);
        this.movies = append ? [...this.movies, ...mapped] : mapped;
        this.currentPage = Number(data.page || page);
        this.pagecount = Number(data.pagecount || 1);
        this.hasMore = Boolean(data.hasMore);
        this.saveHomeState(false);
      } finally {
        this.isLoading = false;
        this.$nextTick(() => this.triggerAutoLoadIfNeeded());
      }
    },
    async fetchSearchMovies(page = 1, append = false) {
      this.isLoading = true;
      try {
        const data = await window.EsirtvApi.search(this.site, this.activeKeyword, page);
        const mapped = this.mapMovies(data.list);
        this.movies = append ? [...this.movies, ...mapped] : mapped;
        this.currentPage = Number(data.page || page);
        this.pagecount = Number(data.pagecount || 1);
        this.hasMore = Boolean(data.hasMore);
        this.saveHomeState(false);
      } finally {
        this.isLoading = false;
        this.$nextTick(() => this.triggerAutoLoadIfNeeded());
      }
    },
    async fetchHistory() {
      this.isLoading = true;
      try {
        const list = await window.EsirtvApi.getHistory(this.site, 200);
        this.movies = this.mapRecordItems(list);
        this.currentPage = 1;
        this.pagecount = 1;
        this.hasMore = false;
        this.saveHomeState(true);
      } finally {
        this.isLoading = false;
      }
    },
    async fetchFavorites() {
      this.isLoading = true;
      try {
        const list = await window.EsirtvApi.getFavorites(this.site);
        this.movies = this.mapRecordItems(list);
        this.currentPage = 1;
        this.pagecount = 1;
        this.hasMore = false;
        this.saveHomeState(true);
      } finally {
        this.isLoading = false;
      }
    },
    async loadMore() {
      if (!this.hasMore || this.isLoading) {
        return;
      }
      if (this.currentType === HISTORY_TYPE_ID || this.currentType === FAVORITES_TYPE_ID) {
        return;
      }
      try {
        if (this.searchMode) {
          await this.fetchSearchMovies(this.currentPage + 1, true);
        } else {
          await this.fetchMovies(this.currentPage + 1, true);
        }
      } catch (error) {
        this.errorMsg = error.message || '加载更多失败';
      }
    },
    async filterType(typeId) {
      const normalizedType = Number(typeId);
      if (this.currentType === normalizedType && this.movies.length > 0) {
        return;
      }
      try {
        this.errorMsg = '';
        this.searchMode = false;
        this.activeKeyword = '';
        this.keyword = '';
        this.currentType = normalizedType;
        this.currentPage = 1;
        this.movies = [];

        if (normalizedType === HISTORY_TYPE_ID) {
          await this.fetchHistory();
        } else if (normalizedType === FAVORITES_TYPE_ID) {
          await this.fetchFavorites();
        } else {
          await this.fetchMovies(1, false);
        }

        this.saveHomeState(true);
        window.scrollTo({ top: 0, behavior: 'smooth' });
      } catch (error) {
        this.errorMsg = error.message || '分类加载失败';
      }
    },
    async switchSite(siteKey) {
      try {
        this.errorMsg = '';
        this.site = siteKey;
        this.currentType = HISTORY_TYPE_ID;
        this.activeKeyword = '';
        this.keyword = '';
        this.searchMode = false;
        this.movies = [];
        this.saveAndResetListState();
        await this.fetchTypes();
        await this.fetchHistory();
      } catch (error) {
        this.errorMsg = error.message || '切换站点失败';
      }
    },
    async searchMovies() {
      const keyword = this.keyword.trim();
      if (!keyword) {
        this.errorMsg = '请输入关键词后再搜索。';
        return;
      }
      try {
        this.errorMsg = '';
        this.activeKeyword = keyword;
        this.searchMode = true;
        this.currentPage = 1;
        this.movies = [];
        await this.fetchSearchMovies(1, false);
        this.saveHomeState(true);
        window.scrollTo({ top: 0, behavior: 'smooth' });
      } catch (error) {
        this.errorMsg = error.message || '搜索失败';
      }
    },
    async clearSearch() {
      try {
        this.errorMsg = '';
        this.keyword = '';
        this.activeKeyword = '';
        this.searchMode = false;
        this.currentPage = 1;
        this.movies = [];
        if (this.currentType === HISTORY_TYPE_ID) {
          await this.fetchHistory();
        } else if (this.currentType === FAVORITES_TYPE_ID) {
          await this.fetchFavorites();
        } else {
          await this.fetchMovies(1, false);
        }
        this.saveHomeState(true);
      } catch (error) {
        this.errorMsg = error.message || '清空搜索失败';
      }
    },
    goDetail(movie) {
      const targetSite = movie.site || this.site;
      const vodId = movie.vod_id || movie.id;
      this.saveHomeState(true);
      const url = `./detail.html?site=${encodeURIComponent(targetSite)}&vod_id=${encodeURIComponent(vodId)}`;
      window.location.href = url;
    },
    async resetHome() {
      this.keyword = '';
      this.activeKeyword = '';
      this.searchMode = false;
      await this.filterType(HISTORY_TYPE_ID);
    },
    isKnownType(typeId) {
      if (typeId === HISTORY_TYPE_ID || typeId === FAVORITES_TYPE_ID) {
        return true;
      }
      return this.types.some((item) => Number(item.type_id) === Number(typeId));
    },
    async init() {
      try {
        const params = new URLSearchParams(window.location.search);
        const fromSite = params.get('site');
        const saved = this.loadHomeState();

        await this.fetchSites();
        const validSite = (candidate) => this.sites.some((item) => (item.key || item.name) === candidate);

        if (fromSite && validSite(fromSite)) {
          this.site = fromSite;
        } else if (saved.site && validSite(saved.site)) {
          this.site = saved.site;
        }

        if (!this.site) {
          this.errorMsg = '暂无可用站点，请先到设置页配置数据源链接。';
          return;
        }

        this.errorMsg = '';
        await this.fetchTypes();

        if (this.canRestoreHomeState(saved, this.site) && this.isKnownType(Number(saved.typeId))) {
          this.restoreHomeState(saved);
          this.saveHomeState(false);
          return;
        }

        const savedTypeId = Number(saved.typeId);
        this.currentType = this.isKnownType(savedTypeId) ? savedTypeId : HISTORY_TYPE_ID;

        if (saved.keyword) {
          this.keyword = saved.keyword;
          this.activeKeyword = saved.keyword;
          this.searchMode = true;
          await this.fetchSearchMovies(1, false);
        } else if (this.currentType === HISTORY_TYPE_ID) {
          await this.fetchHistory();
        } else if (this.currentType === FAVORITES_TYPE_ID) {
          await this.fetchFavorites();
        } else {
          await this.fetchMovies(1, false);
        }

        this.saveHomeState(true);
      } catch (error) {
        this.errorMsg = error.message || '初始化失败';
      }
    },
  },
  mounted() {
    window.addEventListener('scroll', this.onScrollSave, { passive: true });
    window.addEventListener('beforeunload', () => this.saveHomeState(true));
    this.$nextTick(() => this.setupAutoLoadObserver());
    this.init();
  },
  beforeUnmount() {
    window.removeEventListener('scroll', this.onScrollSave);
    this.tearDownAutoLoadObserver();
    if (this.saveTimer) {
      clearTimeout(this.saveTimer);
      this.saveTimer = null;
    }
    this.saveHomeState(true);
  },
}).mount('#app');

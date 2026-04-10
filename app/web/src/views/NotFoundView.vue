<template>
  <main class="max-w-3xl mx-auto p-6">
    <div class="glass-effect rounded-xl p-6 border border-slate-800">
      <h1 class="text-2xl font-bold mb-3">页面不存在</h1>
      <p class="text-slate-300 mb-4">你访问的地址不存在或已被迁移。</p>
      <router-link class="inline-flex items-center gap-2 bg-slate-800 hover:bg-slate-700 px-3 py-2 rounded-lg text-sm" to="/">
        <i class="fa-solid fa-house"></i>
        返回首页
      </router-link>
    </div>
  </main>
</template>


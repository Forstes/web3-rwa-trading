<script setup lang="ts">
import router from "@/plugins/router";
import { useWallet, address } from "@/scripts/wallet";
import { onMounted } from "vue";
const { connect } = useWallet();

onMounted(async () => {
  await connect();
});
</script>

<template>
  <div class="h-screen flex flex-col overflow-hidden bg-gray-50">
    <nav class="sticky z-20 border-gray-200 px-4 py-2.5 bg-gray-100">
      <div class="flex flex-wrap items-center justify-between">
        <a class="cursor-pointer">
          <span class="text-xl font-semibold" @click="router.push('/')">Logo</span>
        </a>

        <div class="w-auto cursor-pointer" @click="router.push('/')">
          {{ address }}
        </div>
      </div>
    </nav>

    <main class="grow overflow-auto p-2">
      <router-view />
    </main>
  </div>
</template>

<script setup lang="ts">
import router from "@/plugins/router";
import { useWallet, address } from "@/scripts/wallet";
import { onMounted } from "vue";
const { connect } = useWallet();
</script>

<template>
  <div class="h-screen flex flex-col overflow-hidden bg-gray-50">
    <nav class="sticky z-20 border-gray-200 px-4 py-2.5 bg-gray-100">
      <div class="flex flex-wrap items-center justify-between">
        <div class="w-auto cursor-pointer" @click="router.push('/')">
          {{ address }}
        </div>

        <a class="cursor-pointer">
          <span class="font-semibold mr-3 hover:text-rose-500" @click="router.push('/mint')">New offer</span>
          <span class="font-semibold hover:text-rose-500" @click="router.push('/')">My bids</span>
        </a>
      </div>
    </nav>

    <main class="grow overflow-auto p-2">
      <router-view />
    </main>
  </div>
</template>

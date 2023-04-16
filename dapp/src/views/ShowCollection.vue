<script setup lang="ts">
import { EXCHANGE_ADDRESS, EXCHANGE_ABI } from "@/constants/index";
import { useWallet, address, signer } from "@/scripts/wallet";
import { Contract, ethers } from "ethers";
import { onMounted, ref } from "vue";

const { connect } = useWallet();
let exchange: Contract;

const offers = ref();

onMounted(async () => {
  connect()
    .then(async (signer) => {
      exchange = new ethers.Contract(EXCHANGE_ADDRESS, EXCHANGE_ABI, signer);
      offers.value = await exchange.getOffers(0, 25);
      console.log(offers.value);
    })
    .catch((e) => alert(e));
});
</script>

<template>
  <div class="w-full h-full py-8 flex justify-center items-start flex-wrap gap-5">
    <div class="w-48 min-h-32 border rounded-lg text-center p-3 py-6 cursor-pointer hover:scale-105" v-for="i in 5">
      <h2>Asset {{ i }}</h2>
      <img src="/assets/asset.png" class="w-16 h-16 mx-auto" />
      <p class="text-lime-500">{{ 50 * i }} USDT</p>
    </div>
  </div>
</template>

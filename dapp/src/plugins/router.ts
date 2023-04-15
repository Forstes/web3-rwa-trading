import { createRouter, createWebHistory } from "vue-router";

const routes = [
  {
    path: "/",
    component: () => import("@/views/ShowCollection.vue"),
  },
  {
    path: "/mint",
    component: () => import("@/views/Mint.vue"),
  },
];

const router = createRouter({
  history: createWebHistory(),
  routes,
});

export default router;

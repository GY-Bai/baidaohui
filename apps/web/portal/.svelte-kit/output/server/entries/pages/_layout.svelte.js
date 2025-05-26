import { c as create_ssr_component } from "../../chunks/ssr.js";
const app = "";
const Layout = create_ssr_component(($$result, $$props, $$bindings, slots) => {
  return `<main class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">${slots.default ? slots.default({}) : ``}</main>`;
});
export {
  Layout as default
};

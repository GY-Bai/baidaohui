import { c as create_ssr_component } from "../../../chunks/ssr.js";
const _page_svelte_svelte_type_style_lang = "";
const css = {
  code: ".container.svelte-xx7ncv{padding:2rem;text-align:center}h1.svelte-xx7ncv{color:#333;margin-bottom:1rem}p.svelte-xx7ncv{color:#666}",
  map: null
};
const Page = create_ssr_component(($$result, $$props, $$bindings, slots) => {
  $$result.css.add(css);
  return `${$$result.head += `<!-- HEAD_svelte-1my3sla_START -->${$$result.title = `<title>百刀会 - 算命</title>`, ""}<meta name="description" content="百刀会算命服务"><!-- HEAD_svelte-1my3sla_END -->`, ""} <div class="container svelte-xx7ncv" data-svelte-h="svelte-1j2jkou"><h1 class="svelte-xx7ncv">🔮 算命服务</h1> <p class="svelte-xx7ncv">算命功能正在开发中...</p> </div>`;
});
export {
  Page as default
};

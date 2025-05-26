import { c as create_ssr_component } from "../../chunks/ssr.js";
const _page_svelte_svelte_type_style_lang = "";
const css = {
  code: "main.svelte-cjngte{padding:2rem;text-align:center}h1.svelte-cjngte{color:#333;margin-bottom:1rem}",
  map: null
};
const Page = create_ssr_component(($$result, $$props, $$bindings, slots) => {
  $$result.css.add(css);
  return `${$$result.head += `<!-- HEAD_svelte-1awel78_START -->${$$result.title = `<title>Fan - 百道会</title>`, ""}<!-- HEAD_svelte-1awel78_END -->`, ""} <main class="svelte-cjngte" data-svelte-h="svelte-1ys005v"><h1 class="svelte-cjngte">欢迎来到 Fan 页面</h1> <p>这是百道会 Fan 应用的主页。</p> </main>`;
});
export {
  Page as default
};

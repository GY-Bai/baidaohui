

export const index = 7;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/shop/_page.svelte.js')).default;
export const imports = ["_app/immutable/nodes/7.e194c2ff.js","_app/immutable/chunks/scheduler.a1aa4b3e.js","_app/immutable/chunks/index.e0a59431.js"];
export const stylesheets = ["_app/immutable/assets/4.d00b59ad.css"];
export const fonts = [];

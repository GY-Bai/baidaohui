

export const index = 2;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/_page.svelte.js')).default;
export const imports = ["_app/immutable/nodes/2.26d410c4.js","_app/immutable/chunks/2.7cf0131c.js","_app/immutable/chunks/scheduler.63274e7e.js","_app/immutable/chunks/index.0f2d9a80.js","_app/immutable/chunks/paths.817494a7.js","_app/immutable/chunks/preload-helper.a4192956.js"];
export const stylesheets = ["_app/immutable/assets/2.4aa556dd.css"];
export const fonts = [];

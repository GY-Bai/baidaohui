

export const index = 1;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/fallbacks/error.svelte.js')).default;
export const imports = ["_app/immutable/nodes/1.5d77ad89.js","_app/immutable/chunks/scheduler.63274e7e.js","_app/immutable/chunks/index.0f2d9a80.js","_app/immutable/chunks/singletons.d56ca058.js","_app/immutable/chunks/paths.817494a7.js"];
export const stylesheets = [];
export const fonts = [];

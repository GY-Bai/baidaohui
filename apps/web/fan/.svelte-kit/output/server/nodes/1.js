

export const index = 1;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/fallbacks/error.svelte.js')).default;
export const imports = ["_app/immutable/nodes/1.f752cf12.js","_app/immutable/chunks/scheduler.a1aa4b3e.js","_app/immutable/chunks/index.e0a59431.js","_app/immutable/chunks/singletons.9287b66d.js"];
export const stylesheets = [];
export const fonts = [];

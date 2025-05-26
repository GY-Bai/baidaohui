

export const index = 5;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/fortune/new/_page.svelte.js')).default;
export const imports = ["_app/immutable/nodes/5.eecaf5dc.js","_app/immutable/chunks/scheduler.a1aa4b3e.js","_app/immutable/chunks/index.e0a59431.js","_app/immutable/chunks/singletons.9287b66d.js"];
export const stylesheets = [];
export const fonts = [];

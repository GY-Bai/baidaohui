

export const index = 0;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/_layout.svelte.js')).default;
export const imports = ["_app/immutable/nodes/0.6c83c79b.js","_app/immutable/chunks/scheduler.63274e7e.js","_app/immutable/chunks/index.0f2d9a80.js"];
export const stylesheets = ["_app/immutable/assets/0.a1239d76.css"];
export const fonts = [];

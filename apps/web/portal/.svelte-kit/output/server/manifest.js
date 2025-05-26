export const manifest = (() => {
function __memo(fn) {
	let value;
	return () => value ??= (value = fn());
}

return {
	appDir: "_app",
	appPath: "_app",
	assets: new Set(["apple-touch-icon-precomposed.png","apple-touch-icon.png","assets/pic/favicon.png","favicon.ico","favicon.png"]),
	mimeTypes: {".png":"image/png"},
	_: {
		client: {"start":"_app/immutable/entry/start.79511fcc.js","app":"_app/immutable/entry/app.8e66d988.js","imports":["_app/immutable/entry/start.79511fcc.js","_app/immutable/chunks/scheduler.63274e7e.js","_app/immutable/chunks/singletons.d56ca058.js","_app/immutable/chunks/paths.817494a7.js","_app/immutable/entry/app.8e66d988.js","_app/immutable/chunks/preload-helper.a4192956.js","_app/immutable/chunks/scheduler.63274e7e.js","_app/immutable/chunks/index.0f2d9a80.js"],"stylesheets":[],"fonts":[]},
		nodes: [
			__memo(() => import('./nodes/0.js')),
			__memo(() => import('./nodes/1.js')),
			__memo(() => import('./nodes/2.js'))
		],
		routes: [
			{
				id: "/",
				pattern: /^\/$/,
				params: [],
				page: { layouts: [0,], errors: [1,], leaf: 2 },
				endpoint: null
			}
		],
		matchers: async () => {
			
			return {  };
		}
	}
}
})();

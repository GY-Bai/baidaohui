export { matchers } from './matchers.js';

export const nodes = [
	() => import('./nodes/0'),
	() => import('./nodes/1'),
	() => import('./nodes/2'),
	() => import('./nodes/3'),
	() => import('./nodes/4'),
	() => import('./nodes/5'),
	() => import('./nodes/6'),
	() => import('./nodes/7'),
	() => import('./nodes/8'),
	() => import('./nodes/9'),
	() => import('./nodes/10'),
	() => import('./nodes/11'),
	() => import('./nodes/12'),
	() => import('./nodes/13'),
	() => import('./nodes/14'),
	() => import('./nodes/15')
];

export const server_loads = [2,3,4,5,6];

export const dictionary = {
		"/auth/callback": [~7],
		"/chat/group/general": [8],
		"/chat/private/[memberId]": [9],
		"/fan": [10,[2]],
		"/firstmate": [11,[3]],
		"/login": [~12],
		"/master": [13,[4]],
		"/member": [14,[5]],
		"/seller": [15,[6]]
	};

export const hooks = {
	handleError: (({ error }) => { console.error(error) }),
};

export { default as root } from '../root.svelte';
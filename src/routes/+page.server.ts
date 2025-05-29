export const prerender = false;
import { redirect } from '@sveltejs/kit';

// 根路径直接重定向到登录页，不做任何API调用
export const load = async () => {
  throw redirect(302, '/login');
};

import { createRouteGuard } from '$lib/auth';

export const load = async ({ url, cookies, fetch }) => {
  return await createRouteGuard('Fan', url, cookies, fetch);
}; 
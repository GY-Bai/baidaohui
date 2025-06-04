-- 修复无限递归问题
-- 删除造成无限递归的策略
DROP POLICY IF EXISTS "profiles_read_admin" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_admin" ON public.profiles;
DROP POLICY IF EXISTS "profiles_debug_read" ON public.profiles;

-- 只保留简单的策略，避免递归
-- 用户只能读取和更新自己的记录
CREATE POLICY "profiles_read_own_simple" ON public.profiles
FOR SELECT
USING (auth.uid() = id);

CREATE POLICY "profiles_update_own_simple" ON public.profiles
FOR UPDATE
USING (auth.uid() = id); 
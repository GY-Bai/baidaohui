-- 清理重复的策略
DROP POLICY IF EXISTS "profiles_read_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;

-- 保留简单的策略
-- profiles_read_own_simple 和 profiles_update_own_simple 已经存在，无需重复创建 
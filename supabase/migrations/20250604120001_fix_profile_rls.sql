-- 修复 profiles 表的 RLS 策略
-- 删除现有的有问题的策略
DROP POLICY IF EXISTS "profiles_select_admin" ON public.profiles;
DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;

-- 创建新的更宽松的策略
CREATE POLICY "profiles_read_own" ON public.profiles
FOR SELECT
USING (auth.uid() = id);

-- 创建管理员可以读取所有用户的策略
CREATE POLICY "profiles_read_admin" ON public.profiles
FOR SELECT
USING (
  auth.uid() IN (
    SELECT id FROM public.profiles 
    WHERE role IN ('Master', 'Firstmate') 
    AND id = auth.uid()
  )
);

-- 确保用户可以更新自己的记录
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_admin" ON public.profiles;

CREATE POLICY "profiles_update_own" ON public.profiles
FOR UPDATE
USING (auth.uid() = id);

-- 管理员可以更新所有用户
CREATE POLICY "profiles_update_admin" ON public.profiles
FOR UPDATE
USING (
  auth.uid() IN (
    SELECT id FROM public.profiles 
    WHERE role IN ('Master', 'Firstmate') 
    AND id = auth.uid()
  )
); 
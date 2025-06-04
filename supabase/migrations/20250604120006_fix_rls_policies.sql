-- 修复 RLS 策略
-- 1. 首先清理现有策略，重新开始
DROP POLICY IF EXISTS "profiles_read_own_simple" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own_simple" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_system" ON public.profiles;

-- 2. 确保 profiles 表启用 RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 3. 创建辅助函数：判断当前用户是否为 master 或 firstmaster
CREATE OR REPLACE FUNCTION public.is_master_or_firstmaster()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM public.profiles 
    WHERE id = auth.uid() 
    AND role IN ('Master', 'Firstmate')
  );
$$;

-- 4. 创建公共视图：只暴露 id 和 role，供所有用户查询
DROP VIEW IF EXISTS public.profiles_public_roles;
CREATE VIEW public.profiles_public_roles AS
SELECT id, role
FROM public.profiles;

-- 5. 为公共视图授予 SELECT 权限给所有用户
GRANT SELECT ON public.profiles_public_roles TO public;
GRANT SELECT ON public.profiles_public_roles TO anon;
GRANT SELECT ON public.profiles_public_roles TO authenticated;

-- 6. 创建 RLS 策略

-- 6.1 SELECT 策略：允许本人或管理员查询整行
CREATE POLICY "profiles_select_owner_or_admin" ON public.profiles
FOR SELECT
USING (
  auth.uid() = id OR public.is_master_or_firstmaster()
);

-- 6.2 UPDATE 策略1：只允许管理员更新（包括角色）
CREATE POLICY "profiles_update_by_admins" ON public.profiles
FOR UPDATE
USING (public.is_master_or_firstmaster())
WITH CHECK (public.is_master_or_firstmaster());

-- 6.3 UPDATE 策略2：只允许本人更新（但我们将通过应用层控制不允许修改角色）
CREATE POLICY "profiles_update_by_owner" ON public.profiles
FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- 6.4 INSERT 策略：允许系统插入新用户（用于注册流程）
CREATE POLICY "profiles_insert_system" ON public.profiles
FOR INSERT
WITH CHECK (true);

-- 7. 为辅助函数授予执行权限
GRANT EXECUTE ON FUNCTION public.is_master_or_firstmaster() TO public;
GRANT EXECUTE ON FUNCTION public.is_master_or_firstmaster() TO anon;
GRANT EXECUTE ON FUNCTION public.is_master_or_firstmaster() TO authenticated;

-- 8. 创建一个触发器函数来防止普通用户修改自己的角色
CREATE OR REPLACE FUNCTION public.prevent_role_change_by_non_admin()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 如果是管理员，允许所有修改
  IF public.is_master_or_firstmaster() THEN
    RETURN NEW;
  END IF;
  
  -- 如果是普通用户修改自己的记录
  IF auth.uid() = NEW.id THEN
    -- 如果尝试修改角色，阻止修改
    IF OLD.role IS DISTINCT FROM NEW.role THEN
      RAISE EXCEPTION 'Only administrators can modify user roles';
    END IF;
    RETURN NEW;
  END IF;
  
  -- 其他情况不允许
  RAISE EXCEPTION 'Access denied';
END;
$$;

-- 9. 创建触发器
DROP TRIGGER IF EXISTS trigger_prevent_role_change ON public.profiles;
CREATE TRIGGER trigger_prevent_role_change
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_role_change_by_non_admin(); 
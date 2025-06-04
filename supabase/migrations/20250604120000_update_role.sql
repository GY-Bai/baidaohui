-- 更新指定用户的角色
BEGIN;

-- 更新 profiles 表的角色字段
UPDATE public.profiles
SET role = 'Master'
WHERE email = 'baigengyuan319@gmail.com';

-- 提交更改
COMMIT;

-- 如果需要，回滚示例（可选）
-- ROLLBACK;

-- 添加触发器来记录角色更新
CREATE OR REPLACE FUNCTION public.log_role_change()
RETURNS TRIGGER AS $$
BEGIN
    -- 记录角色变化到 audit_logs 表（假设您有这个表）
    INSERT INTO public.audit_logs (user_id, action, details)
    VALUES (NEW.id, 'ROLE_UPDATED', 'Role changed to ' || NEW.role);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为 profiles 表创建触发器
CREATE TRIGGER trigger_after_role_update
AFTER UPDATE OF role ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.log_role_change(); 
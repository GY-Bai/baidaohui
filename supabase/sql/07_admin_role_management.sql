-- 管理员角色管理功能
-- 提供完整的用户角色调整和同步功能

-- ========================================
-- 1. 单个用户角色调整函数（Master专用）
-- ========================================

CREATE OR REPLACE FUNCTION public.admin_change_user_role(
    target_user_id UUID,
    new_role TEXT,
    reason TEXT DEFAULT '管理员手动调整'
)
RETURNS JSONB AS $$
DECLARE
    current_user_id UUID;
    current_user_role TEXT;
    target_user_record public.profiles%ROWTYPE;
    old_role TEXT;
BEGIN
    -- 获取当前用户信息
    current_user_id := auth.uid();
    current_user_role := COALESCE(auth.jwt() ->> 'role', 'Fan');
    
    -- 权限检查：只有Master可以调整角色
    IF current_user_role != 'Master' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'insufficient_permissions',
            'message', '只有Master可以调整用户角色'
        );
    END IF;
    
    -- 验证新角色
    IF new_role NOT IN ('Fan', 'Member', 'Master', 'Firstmate', 'Seller') THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'invalid_role',
            'message', '无效的角色：' || new_role
        );
    END IF;
    
    -- 获取目标用户当前信息
    SELECT * INTO target_user_record FROM public.profiles WHERE id = target_user_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'user_not_found',
            'message', '目标用户不存在'
        );
    END IF;
    
    old_role := target_user_record.role;
    
    -- 如果角色相同，无需更新
    IF old_role = new_role THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', '用户角色无需更新',
            'user_id', target_user_id,
            'email', target_user_record.email,
            'role', new_role
        );
    END IF;
    
    -- 记录操作到审计日志
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        old_values,
        new_values
    ) VALUES (
        current_user_id,
        'admin_role_change',
        'profiles',
        target_user_id::TEXT,
        jsonb_build_object(
            'target_user_id', target_user_id,
            'target_email', target_user_record.email,
            'old_role', old_role,
            'reason', reason,
            'changed_by', current_user_id
        ),
        jsonb_build_object(
            'target_user_id', target_user_id,
            'target_email', target_user_record.email,
            'new_role', new_role,
            'reason', reason,
            'changed_by', current_user_id,
            'changed_at', NOW()
        )
    );
    
    -- 更新用户角色
    UPDATE public.profiles
    SET 
        role = new_role,
        updated_at = NOW()
    WHERE id = target_user_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', '用户角色调整成功',
        'user_id', target_user_id,
        'email', target_user_record.email,
        'old_role', old_role,
        'new_role', new_role,
        'reason', reason,
        'changed_by', current_user_id,
        'changed_at', NOW(),
        'notice', '用户需要重新登录以获取新的权限'
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'operation_failed',
            'message', '角色调整失败：' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- 2. 通过邮箱查找并调整角色
-- ========================================

CREATE OR REPLACE FUNCTION public.admin_change_role_by_email(
    target_email TEXT,
    new_role TEXT,
    reason TEXT DEFAULT '管理员手动调整'
)
RETURNS JSONB AS $$
DECLARE
    target_user_id UUID;
BEGIN
    -- 通过邮箱查找用户ID
    SELECT id INTO target_user_id 
    FROM public.profiles 
    WHERE email = target_email;
    
    IF target_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'user_not_found',
            'message', '未找到邮箱为 ' || target_email || ' 的用户'
        );
    END IF;
    
    -- 调用主函数
    RETURN public.admin_change_user_role(target_user_id, new_role, reason);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- 3. 查看用户角色调整历史
-- ========================================

CREATE OR REPLACE FUNCTION public.admin_get_role_change_history(
    target_user_id UUID DEFAULT NULL,
    limit_count INTEGER DEFAULT 20
)
RETURNS TABLE (
    id UUID,
    changed_at TIMESTAMPTZ,
    target_user_email TEXT,
    old_role TEXT,
    new_role TEXT,
    reason TEXT,
    changed_by_id UUID,
    action TEXT
) AS $$
DECLARE
    current_user_role TEXT;
BEGIN
    -- 权限检查
    current_user_role := COALESCE(auth.jwt() ->> 'role', 'Fan');
    
    IF current_user_role NOT IN ('Master', 'Firstmate') THEN
        RAISE EXCEPTION 'insufficient_permissions';
    END IF;
    
    RETURN QUERY
    SELECT 
        al.id,
        al.created_at as changed_at,
        (al.old_values->>'target_email')::TEXT as target_user_email,
        (al.old_values->>'old_role')::TEXT as old_role,
        (al.new_values->>'new_role')::TEXT as new_role,
        (al.old_values->>'reason')::TEXT as reason,
        (al.old_values->>'changed_by')::UUID as changed_by_id,
        al.action
    FROM public.audit_logs al
    WHERE al.action = 'admin_role_change'
      AND (target_user_id IS NULL OR (al.old_values->>'target_user_id')::UUID = target_user_id)
    ORDER BY al.created_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- 4. 获取所有用户列表（供管理员查看）
-- ========================================

CREATE OR REPLACE FUNCTION public.admin_list_users(
    role_filter TEXT DEFAULT NULL,
    limit_count INTEGER DEFAULT 50
)
RETURNS TABLE (
    id UUID,
    email TEXT,
    role TEXT,
    nickname TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
DECLARE
    current_user_role TEXT;
BEGIN
    -- 权限检查
    current_user_role := COALESCE(auth.jwt() ->> 'role', 'Fan');
    
    IF current_user_role NOT IN ('Master', 'Firstmate') THEN
        RAISE EXCEPTION 'insufficient_permissions';
    END IF;
    
    RETURN QUERY
    SELECT 
        p.id,
        p.email,
        p.role,
        p.nickname,
        p.created_at,
        p.updated_at
    FROM public.profiles p
    WHERE (role_filter IS NULL OR p.role = role_filter)
    ORDER BY p.created_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- 5. 强制用户重新登录（通过标记）
-- ========================================

-- 创建一个表来跟踪需要重新登录的用户
CREATE TABLE IF NOT EXISTS public.force_relogin (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 启用RLS
ALTER TABLE public.force_relogin ENABLE ROW LEVEL SECURITY;

-- 只有系统可以操作这个表
CREATE POLICY "force_relogin_system_only" ON public.force_relogin
    FOR ALL
    USING (false)
    WITH CHECK (false);

-- 创建标记用户需要重新登录的函数
CREATE OR REPLACE FUNCTION public.admin_force_user_relogin(
    target_user_id UUID,
    reason TEXT DEFAULT '角色已更新，需要重新登录'
)
RETURNS JSONB AS $$
DECLARE
    current_user_role TEXT;
BEGIN
    -- 权限检查
    current_user_role := COALESCE(auth.jwt() ->> 'role', 'Fan');
    
    IF current_user_role NOT IN ('Master', 'Firstmate') THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'insufficient_permissions',
            'message', '权限不足'
        );
    END IF;
    
    -- 添加到强制重新登录表
    INSERT INTO public.force_relogin (user_id, reason)
    VALUES (target_user_id, reason)
    ON CONFLICT (user_id) DO UPDATE SET
        reason = EXCLUDED.reason,
        created_at = NOW();
    
    RETURN jsonb_build_object(
        'success', true,
        'message', '已标记用户需要重新登录',
        'user_id', target_user_id,
        'reason', reason
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- 6. 检查用户是否需要重新登录
-- ========================================

CREATE OR REPLACE FUNCTION public.check_force_relogin()
RETURNS JSONB AS $$
DECLARE
    current_user_id UUID;
    relogin_record RECORD;
BEGIN
    current_user_id := auth.uid();
    
    IF current_user_id IS NULL THEN
        RETURN jsonb_build_object('force_relogin', false);
    END IF;
    
    -- 检查是否需要重新登录
    SELECT * INTO relogin_record 
    FROM public.force_relogin 
    WHERE user_id = current_user_id;
    
    IF FOUND THEN
        -- 删除记录（避免重复提醒）
        DELETE FROM public.force_relogin WHERE user_id = current_user_id;
        
        RETURN jsonb_build_object(
            'force_relogin', true,
            'reason', relogin_record.reason,
            'marked_at', relogin_record.created_at
        );
    END IF;
    
    RETURN jsonb_build_object('force_relogin', false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- 7. 添加函数注释
-- ========================================

COMMENT ON FUNCTION public.admin_change_user_role(UUID, TEXT, TEXT) IS 'Master调整用户角色';
COMMENT ON FUNCTION public.admin_change_role_by_email(TEXT, TEXT, TEXT) IS '通过邮箱调整用户角色';
COMMENT ON FUNCTION public.admin_get_role_change_history(UUID, INTEGER) IS '查看角色调整历史';
COMMENT ON FUNCTION public.admin_list_users(TEXT, INTEGER) IS '管理员查看用户列表';
COMMENT ON FUNCTION public.admin_force_user_relogin(UUID, TEXT) IS '标记用户需要重新登录';
COMMENT ON FUNCTION public.check_force_relogin() IS '检查当前用户是否需要重新登录';

COMMENT ON TABLE public.force_relogin IS '强制重新登录标记表'; 
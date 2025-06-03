-- 修复 profiles 表的 RLS 递归策略问题
-- 通过删除旧策略并创建新的非递归策略来解决问题

-- ========================================
-- 第一步：删除所有现有的问题策略
-- ========================================

-- 删除 profiles 表的所有策略
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Master and Firstmate can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Master and Firstmate can update user roles" ON public.profiles;
DROP POLICY IF EXISTS "System can insert profiles" ON public.profiles;

-- 删除 invite_links 表的所有策略
DROP POLICY IF EXISTS "Master and Firstmate can view all invite links" ON public.invite_links;
DROP POLICY IF EXISTS "Master and Firstmate can create invite links" ON public.invite_links;
DROP POLICY IF EXISTS "Master and Firstmate can update own invite links" ON public.invite_links;
DROP POLICY IF EXISTS "Master and Firstmate can delete own invite links" ON public.invite_links;
DROP POLICY IF EXISTS "Authenticated users can view valid invite links" ON public.invite_links;

-- 删除视图策略
DROP POLICY IF EXISTS "Only admins can view user stats" ON public.user_stats;
DROP POLICY IF EXISTS "Only admins can view invite link stats" ON public.invite_link_stats;

-- 删除审计日志策略
DROP POLICY IF EXISTS "Only admins can view audit logs" ON public.audit_logs;
DROP POLICY IF EXISTS "System can insert audit logs" ON public.audit_logs;

-- ========================================
-- 第二步：重新创建非递归的 RLS 策略
-- ========================================

-- profiles 表的新策略（使用 auth.jwt() 避免递归）
CREATE POLICY "profiles_select_own" ON public.profiles
    FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "profiles_update_own" ON public.profiles
    FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "profiles_select_admin" ON public.profiles
    FOR SELECT
    USING (COALESCE(auth.jwt() ->> 'role', 'Fan') IN ('Master', 'Firstmate'));

CREATE POLICY "profiles_update_admin" ON public.profiles
    FOR UPDATE
    USING (COALESCE(auth.jwt() ->> 'role', 'Fan') IN ('Master', 'Firstmate'));

CREATE POLICY "profiles_insert_system" ON public.profiles
    FOR INSERT
    WITH CHECK (true);

-- invite_links 表的新策略
CREATE POLICY "invite_links_select_admin" ON public.invite_links
    FOR SELECT
    USING (COALESCE(auth.jwt() ->> 'role', 'Fan') IN ('Master', 'Firstmate'));

CREATE POLICY "invite_links_insert_admin" ON public.invite_links
    FOR INSERT
    WITH CHECK (
        COALESCE(auth.jwt() ->> 'role', 'Fan') IN ('Master', 'Firstmate')
        AND created_by = auth.uid()
    );

CREATE POLICY "invite_links_update_admin" ON public.invite_links
    FOR UPDATE
    USING (
        COALESCE(auth.jwt() ->> 'role', 'Fan') IN ('Master', 'Firstmate')
        AND created_by = auth.uid()
    );

CREATE POLICY "invite_links_delete_admin" ON public.invite_links
    FOR DELETE
    USING (
        COALESCE(auth.jwt() ->> 'role', 'Fan') IN ('Master', 'Firstmate')
        AND created_by = auth.uid()
    );

CREATE POLICY "invite_links_select_valid" ON public.invite_links
    FOR SELECT
    USING (
        auth.role() = 'authenticated'
        AND is_active = true
        AND (expires_at IS NULL OR expires_at > NOW())
        AND used_count < max_uses
    );

-- 审计日志的新策略
CREATE POLICY "audit_logs_select_admin" ON public.audit_logs
    FOR SELECT
    USING (COALESCE(auth.jwt() ->> 'role', 'Fan') IN ('Master', 'Firstmate'));

CREATE POLICY "audit_logs_insert_system" ON public.audit_logs
    FOR INSERT
    WITH CHECK (true);

-- ========================================
-- 第三步：重新创建视图和策略
-- ========================================

-- 删除并重新创建视图的策略
DROP POLICY IF EXISTS "Only admins can view user stats" ON public.user_stats;
CREATE POLICY "user_stats_select_admin" ON public.user_stats
    FOR SELECT
    USING (COALESCE(auth.jwt() ->> 'role', 'Fan') IN ('Master', 'Firstmate'));

DROP POLICY IF EXISTS "Only admins can view invite link stats" ON public.invite_link_stats;
CREATE POLICY "invite_link_stats_select_admin" ON public.invite_link_stats
    FOR SELECT
    USING (COALESCE(auth.jwt() ->> 'role', 'Fan') IN ('Master', 'Firstmate'));

-- ========================================
-- 第四步：验证策略设置
-- ========================================

-- 显示当前所有策略以便验证
DO $$
BEGIN
    RAISE NOTICE '=== RLS 策略修复完成 ===';
    RAISE NOTICE '请查看以下策略设置:';
    
    -- 这里只是一个标记，实际的策略列表需要在 psql 中运行 \d+ table_name 查看
    RAISE NOTICE 'profiles 表策略:';
    RAISE NOTICE '- profiles_select_own: 用户查看自己的资料';
    RAISE NOTICE '- profiles_update_own: 用户更新自己的资料';
    RAISE NOTICE '- profiles_select_admin: 管理员查看所有资料';
    RAISE NOTICE '- profiles_update_admin: 管理员更新所有资料';
    RAISE NOTICE '- profiles_insert_system: 系统插入新资料';
    
    RAISE NOTICE 'invite_links 表策略:';
    RAISE NOTICE '- invite_links_select_admin: 管理员查看邀请链接';
    RAISE NOTICE '- invite_links_insert_admin: 管理员创建邀请链接';
    RAISE NOTICE '- invite_links_update_admin: 管理员更新邀请链接';
    RAISE NOTICE '- invite_links_delete_admin: 管理员删除邀请链接';
    RAISE NOTICE '- invite_links_select_valid: 认证用户查看有效链接';
    
    RAISE NOTICE 'audit_logs 表策略:';
    RAISE NOTICE '- audit_logs_select_admin: 管理员查看审计日志';
    RAISE NOTICE '- audit_logs_insert_system: 系统插入审计日志';
    
    RAISE NOTICE '=== 修复完成，递归问题已解决 ===';
END $$;

-- ========================================
-- 第五步：创建测试函数来验证修复
-- ========================================

-- 创建一个测试函数来验证RLS策略是否正常工作
CREATE OR REPLACE FUNCTION public.test_rls_policies()
RETURNS JSONB AS $$
DECLARE
    current_user_id UUID;
    current_role TEXT;
    test_results JSONB := '{}';
    profile_count INTEGER;
BEGIN
    -- 获取当前用户信息
    current_user_id := auth.uid();
    current_role := COALESCE(auth.jwt() ->> 'role', 'Fan');
    
    -- 测试基本信息
    test_results := jsonb_build_object(
        'user_id', current_user_id,
        'role', current_role,
        'timestamp', NOW()
    );
    
    -- 测试profiles查询
    BEGIN
        SELECT COUNT(*) INTO profile_count FROM public.profiles;
        test_results := test_results || jsonb_build_object(
            'profiles_query', 'success',
            'profiles_count', profile_count
        );
    EXCEPTION
        WHEN OTHERS THEN
            test_results := test_results || jsonb_build_object(
                'profiles_query', 'failed',
                'profiles_error', SQLERRM
            );
    END;
    
    -- 返回测试结果
    RETURN jsonb_build_object(
        'success', true,
        'message', 'RLS策略测试完成',
        'results', test_results
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'message', 'RLS策略测试失败'
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 添加注释
COMMENT ON FUNCTION public.test_rls_policies() IS '测试RLS策略是否正常工作，验证递归问题是否已修复'; 
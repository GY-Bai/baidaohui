-- 配置行级安全策略 (RLS)
-- 确保用户只能访问自己的数据，Master/Firstmate 可以查看所有用户

-- 启用 profiles 表的 RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 启用 invite_links 表的 RLS
ALTER TABLE public.invite_links ENABLE ROW LEVEL SECURITY;

-- ========================================
-- profiles 表的 RLS 策略
-- ========================================

-- 策略1：用户可以查看自己的 profile
CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT
    USING (auth.uid() = id);

-- 策略2：用户可以更新自己的 profile
CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE
    USING (auth.uid() = id);

-- 策略3：Master 和 Firstmate 可以查看所有 profiles
CREATE POLICY "Master and Firstmate can view all profiles" ON public.profiles
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid()
            AND role IN ('Master', 'Firstmate')
        )
    );

-- 策略4：Master 和 Firstmate 可以更新其他用户的角色
CREATE POLICY "Master and Firstmate can update user roles" ON public.profiles
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid()
            AND role IN ('Master', 'Firstmate')
        )
    );

-- 策略5：系统可以插入新的 profile（用于注册触发器）
CREATE POLICY "System can insert profiles" ON public.profiles
    FOR INSERT
    WITH CHECK (true);

-- ========================================
-- invite_links 表的 RLS 策略
-- ========================================

-- 策略1：Master 和 Firstmate 可以查看所有邀请链接
CREATE POLICY "Master and Firstmate can view all invite links" ON public.invite_links
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid()
            AND role IN ('Master', 'Firstmate')
        )
    );

-- 策略2：Master 和 Firstmate 可以创建邀请链接
CREATE POLICY "Master and Firstmate can create invite links" ON public.invite_links
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid()
            AND role IN ('Master', 'Firstmate')
        )
        AND created_by = auth.uid()
    );

-- 策略3：Master 和 Firstmate 可以更新自己创建的邀请链接
CREATE POLICY "Master and Firstmate can update own invite links" ON public.invite_links
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid()
            AND role IN ('Master', 'Firstmate')
        )
        AND created_by = auth.uid()
    );

-- 策略4：Master 和 Firstmate 可以删除自己创建的邀请链接
CREATE POLICY "Master and Firstmate can delete own invite links" ON public.invite_links
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid()
            AND role IN ('Master', 'Firstmate')
        )
        AND created_by = auth.uid()
    );

-- 策略5：所有认证用户可以查看有效的邀请链接（用于验证）
CREATE POLICY "Authenticated users can view valid invite links" ON public.invite_links
    FOR SELECT
    USING (
        auth.role() = 'authenticated'
        AND is_active = true
        AND (expires_at IS NULL OR expires_at > NOW())
        AND used_count < max_uses
    );

-- ========================================
-- 创建安全函数
-- ========================================

-- 创建获取当前用户角色的函数
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS TEXT AS $$
BEGIN
    RETURN (
        SELECT role
        FROM public.profiles
        WHERE id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建检查用户权限的函数
CREATE OR REPLACE FUNCTION public.has_role(required_roles TEXT[])
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (
        SELECT role = ANY(required_roles)
        FROM public.profiles
        WHERE id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建检查是否为管理员的函数
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN public.has_role(ARRAY['Master', 'Firstmate']);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- 创建视图
-- ========================================

-- 创建用户统计视图（仅管理员可见）
CREATE OR REPLACE VIEW public.user_stats AS
SELECT
    role,
    COUNT(*) as user_count,
    COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '30 days') as new_users_30d,
    COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '7 days') as new_users_7d
FROM public.profiles
GROUP BY role;

-- 为视图添加 RLS
ALTER VIEW public.user_stats SET (security_barrier = true);

-- 创建视图的 RLS 策略
CREATE POLICY "Only admins can view user stats" ON public.user_stats
    FOR SELECT
    USING (public.is_admin());

-- 创建邀请链接统计视图
CREATE OR REPLACE VIEW public.invite_link_stats AS
SELECT
    type,
    created_by,
    COUNT(*) as total_links,
    COUNT(*) FILTER (WHERE is_active = true) as active_links,
    COUNT(*) FILTER (WHERE expires_at < NOW()) as expired_links,
    SUM(used_count) as total_uses,
    AVG(used_count::DECIMAL / max_uses) as usage_rate
FROM public.invite_links
GROUP BY type, created_by;

-- 为邀请链接统计视图添加 RLS
ALTER VIEW public.invite_link_stats SET (security_barrier = true);

-- 创建邀请链接统计视图的 RLS 策略
CREATE POLICY "Only admins can view invite link stats" ON public.invite_link_stats
    FOR SELECT
    USING (public.is_admin());

-- ========================================
-- 创建审计日志表
-- ========================================

-- 创建审计日志表
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id),
    action TEXT NOT NULL,
    table_name TEXT NOT NULL,
    record_id TEXT,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 创建审计日志索引
CREATE INDEX idx_audit_logs_user_id ON public.audit_logs(user_id);
CREATE INDEX idx_audit_logs_action ON public.audit_logs(action);
CREATE INDEX idx_audit_logs_table_name ON public.audit_logs(table_name);
CREATE INDEX idx_audit_logs_created_at ON public.audit_logs(created_at);

-- 启用审计日志表的 RLS
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- 审计日志的 RLS 策略：只有管理员可以查看
CREATE POLICY "Only admins can view audit logs" ON public.audit_logs
    FOR SELECT
    USING (public.is_admin());

-- 系统可以插入审计日志
CREATE POLICY "System can insert audit logs" ON public.audit_logs
    FOR INSERT
    WITH CHECK (true);

-- 添加注释
COMMENT ON TABLE public.audit_logs IS '审计日志表，记录重要操作';
COMMENT ON COLUMN public.audit_logs.user_id IS '操作用户ID';
COMMENT ON COLUMN public.audit_logs.action IS '操作类型';
COMMENT ON COLUMN public.audit_logs.table_name IS '操作的表名';
COMMENT ON COLUMN public.audit_logs.record_id IS '操作的记录ID';
COMMENT ON COLUMN public.audit_logs.old_values IS '操作前的值';
COMMENT ON COLUMN public.audit_logs.new_values IS '操作后的值';
COMMENT ON COLUMN public.audit_logs.ip_address IS 'IP地址';
COMMENT ON COLUMN public.audit_logs.user_agent IS '用户代理';
COMMENT ON COLUMN public.audit_logs.created_at IS '创建时间'; 
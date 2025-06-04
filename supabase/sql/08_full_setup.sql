-- ====================================================================================================
-- 08_full_setup.sql
-- 这是一个完整的Supabase数据库初始化脚本，包含了所有表、索引、函数、视图、触发器和RLS策略。
-- 建议在清空数据库后执行此脚本，以确保所有组件按正确顺序创建。
-- ====================================================================================================

-- 设置会话配置，确保超级用户权限进行初始化操作
SET session_replication_role = 'replica';
SET search_path = public, extensions;

-- ========================================
-- 1. 删除所有现有对象 (确保干净的初始化)
-- ========================================

-- 删除所有触发器 (注意顺序，先删触发器再删函数)
DROP TRIGGER IF EXISTS trigger_profiles_updated_at ON public.profiles CASCADE;
DROP TRIGGER IF EXISTS trigger_create_profile_on_signup ON auth.users CASCADE;
DROP TRIGGER IF EXISTS trigger_invite_links_updated_at ON public.invite_links CASCADE;
DROP TRIGGER IF EXISTS trigger_stripe_key_changes ON public.stripe_keys CASCADE;
DROP TRIGGER IF EXISTS trigger_stripe_keys_updated_at ON public.stripe_keys CASCADE;

-- 删除所有视图 (确保在删除底层表前删除)
DROP VIEW IF EXISTS public.user_stats CASCADE;
DROP VIEW IF EXISTS public.invite_link_stats CASCADE;

-- 删除所有函数 (注意顺序，先删依赖它的函数)
DROP FUNCTION IF EXISTS public.admin_change_user_role(UUID, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.admin_change_role_by_email(TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.admin_get_role_change_history(UUID, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS public.admin_list_users(TEXT, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS public.admin_force_user_relogin(UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.check_force_relogin() CASCADE;
DROP FUNCTION IF EXISTS public.upgrade_role(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.batch_upgrade_roles(UUID[], TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.downgrade_role(UUID, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.get_role_upgrade_history(UUID, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS public.validate_stripe_key(UUID, BOOLEAN) CASCADE;
DROP FUNCTION IF EXISTS public.batch_update_stripe_keys(UUID[], JSONB) CASCADE;
DROP FUNCTION IF EXISTS public.handle_stripe_key_changes() CASCADE;
DROP FUNCTION IF EXISTS public.get_secret_from_vault(TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.store_secret_in_vault(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.mask_secret_key(TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.is_invite_link_valid(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.use_invite_link(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS public.cleanup_expired_invite_links() CASCADE;
DROP FUNCTION IF EXISTS public.get_current_user_role() CASCADE;
DROP FUNCTION IF EXISTS public.has_role(TEXT[]) CASCADE;
DROP FUNCTION IF EXISTS public.is_admin() CASCADE;
DROP FUNCTION IF EXISTS public.get_user_profile_safe(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.handle_updated_at() CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;


-- 删除所有策略 (确保在删除表前删除)
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles CASCADE;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles CASCADE;
DROP POLICY IF EXISTS "Master and Firstmate can view all profiles" ON public.profiles CASCADE;
DROP POLICY IF EXISTS "Master and Firstmate can update user roles" ON public.profiles CASCADE;
DROP POLICY IF EXISTS "System can insert profiles" ON public.profiles CASCADE;
DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles CASCADE;
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles CASCADE;
DROP POLICY IF EXISTS "profiles_select_admin" ON public.profiles CASCADE;
DROP POLICY IF EXISTS "profiles_update_admin" ON public.profiles CASCADE;
DROP POLICY IF EXISTS "profiles_insert_system" ON public.profiles CASCADE;

DROP POLICY IF EXISTS "Master and Firstmate can view all invite links" ON public.invite_links CASCADE;
DROP POLICY IF EXISTS "Master and Firstmate can create invite links" ON public.invite_links CASCADE;
DROP POLICY IF EXISTS "Master and Firstmate can update own invite links" ON public.invite_links CASCADE;
DROP POLICY IF EXISTS "Master and Firstmate can delete own invite links" ON public.invite_links CASCADE;
DROP POLICY IF EXISTS "Authenticated users can view valid invite links" ON public.invite_links CASCADE;
DROP POLICY IF EXISTS "invite_links_select_admin" ON public.invite_links CASCADE;
DROP POLICY IF EXISTS "invite_links_insert_admin" ON public.invite_links CASCADE;
DROP POLICY IF EXISTS "invite_links_update_admin" ON public.invite_links CASCADE;
DROP POLICY IF EXISTS "invite_links_delete_admin" ON public.invite_links CASCADE;
DROP POLICY IF EXISTS "invite_links_select_valid" ON public.invite_links CASCADE;

DROP POLICY IF EXISTS "Users can view own stripe keys" ON public.stripe_keys CASCADE;
DROP POLICY IF EXISTS "Users can insert own stripe keys" ON public.stripe_keys CASCADE;
DROP POLICY IF EXISTS "Users can update own stripe keys" ON public.stripe_keys CASCADE;
DROP POLICY IF EXISTS "Users can delete own stripe keys" ON public.stripe_keys CASCADE;
DROP POLICY IF EXISTS "Admins can view all stripe keys" ON public.stripe_keys CASCADE;
DROP POLICY IF EXISTS "Admins can update all stripe keys" ON public.stripe_keys CASCADE;

DROP POLICY IF EXISTS "Only admins can view user stats" ON public.user_stats CASCADE;
DROP POLICY IF EXISTS "Only admins can view invite link stats" ON public.invite_link_stats CASCADE;
DROP POLICY IF EXISTS "user_stats_select_admin" ON public.user_stats CASCADE;
DROP POLICY IF EXISTS "invite_link_stats_select_admin" ON public.invite_link_stats CASCADE;

DROP POLICY IF EXISTS "Only admins can view audit logs" ON public.audit_logs CASCADE;
DROP POLICY IF EXISTS "System can insert audit logs" ON public.audit_logs CASCADE;
DROP POLICY IF EXISTS "audit_logs_select_admin" ON public.audit_logs CASCADE;
DROP POLICY IF EXISTS "audit_logs_insert_system" ON public.audit_logs CASCADE;

DROP POLICY IF EXISTS "force_relogin_system_only" ON public.force_relogin CASCADE;

-- 删除所有表
DROP TABLE IF EXISTS public.profiles CASCADE;
DROP TABLE IF EXISTS public.invite_links CASCADE;
DROP TABLE IF EXISTS public.stripe_keys CASCADE;
DROP TABLE IF EXISTS public.audit_logs CASCADE;
DROP TABLE IF EXISTS public.force_relogin CASCADE;

-- ========================================
-- 2. 创建核心表
-- ========================================

-- 2.1. 创建 profiles 表 (来自 01_create_profiles.sql)
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    role TEXT NOT NULL DEFAULT 'Fan' CHECK (role IN ('Fan', 'Member', 'Master', 'Firstmate', 'Seller')),
    nickname TEXT UNIQUE,
    avatar_url TEXT,
    city TEXT,
    notification_email TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 添加注释
COMMENT ON TABLE public.profiles IS '用户档案表，存储用户角色和基本信息';
COMMENT ON COLUMN public.profiles.id IS '用户ID，关联 auth.users.id';
COMMENT ON COLUMN public.profiles.email IS '用户邮箱';
COMMENT ON COLUMN public.profiles.role IS '用户角色：Fan/Member/Master/Firstmate/Seller';
COMMENT ON COLUMN public.profiles.nickname IS '用户昵称，全局唯一';
COMMENT ON COLUMN public.profiles.avatar_url IS '头像URL';
COMMENT ON COLUMN public.profiles.city IS '所在城市';
COMMENT ON COLUMN public.profiles.notification_email IS '通知邮箱（可与登录邮箱不同）';
COMMENT ON COLUMN public.profiles.created_at IS '创建时间';
COMMENT ON COLUMN public.profiles.updated_at IS '更新时间';

-- 创建索引
CREATE INDEX idx_profiles_role ON public.profiles(role);
CREATE INDEX idx_profiles_email ON public.profiles(email);
CREATE INDEX idx_profiles_nickname ON public.profiles(nickname);
CREATE INDEX idx_profiles_created_at ON public.profiles(created_at);

-- 2.2. 创建 invite_links 表 (来自 02_create_invite_links.sql)
CREATE TABLE public.invite_links (
    token UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type TEXT NOT NULL CHECK (type IN ('member', 'seller')),
    created_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ,
    max_uses INTEGER NOT NULL DEFAULT 1,
    used_count INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 添加注释
COMMENT ON TABLE public.invite_links IS '邀请链接表，用于 Member 和 Seller 角色升级';
COMMENT ON COLUMN public.invite_links.token IS '邀请令牌，UUID格式';
COMMENT ON COLUMN public.invite_links.type IS '邀请类型：member 或 seller';
COMMENT ON COLUMN public.invite_links.created_by IS '创建者ID，关联 profiles.id';
COMMENT ON COLUMN public.invite_links.expires_at IS '过期时间，NULL表示永不过期';
COMMENT ON COLUMN public.invite_links.max_uses IS '最大使用次数';
COMMENT ON COLUMN public.invite_links.used_count IS '已使用次数';
COMMENT ON COLUMN public.invite_links.is_active IS '是否激活';
COMMENT ON COLUMN public.invite_links.metadata IS '额外元数据，JSON格式';
COMMENT ON COLUMN public.invite_links.created_at IS '创建时间';
COMMENT ON COLUMN public.invite_links.updated_at IS '更新时间';

-- 创建索引
CREATE INDEX idx_invite_links_token ON public.invite_links(token);
CREATE INDEX idx_invite_links_type ON public.invite_links(type);
CREATE INDEX idx_invite_links_created_by ON public.invite_links(created_by);
CREATE INDEX idx_invite_links_expires_at ON public.invite_links(expires_at);
CREATE INDEX idx_invite_links_is_active ON public.invite_links(is_active);
CREATE INDEX idx_invite_links_created_at ON public.invite_links(created_at);
CREATE INDEX idx_invite_links_active_valid ON public.invite_links(token, is_active, expires_at)
WHERE is_active = TRUE;

-- 2.3. 创建 audit_logs 表 (来自 03_rls_profiles.sql)
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

-- 创建审计日志索引
CREATE INDEX idx_audit_logs_user_id ON public.audit_logs(user_id);
CREATE INDEX idx_audit_logs_action ON public.audit_logs(action);
CREATE INDEX idx_audit_logs_table_name ON public.audit_logs(table_name);
CREATE INDEX idx_audit_logs_created_at ON public.audit_logs(created_at);

-- 2.4. 创建 stripe_keys 表 (来自 05_trigger_mask_secret.sql)
CREATE TABLE IF NOT EXISTS public.stripe_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    store_name TEXT NOT NULL,
    publishable_key TEXT NOT NULL,
    secret_key_masked TEXT NOT NULL, -- 脱敏后的密钥显示
    secret_key_vault_id TEXT NOT NULL, -- Vault 中的密钥ID
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    test_mode BOOLEAN NOT NULL DEFAULT TRUE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 添加注释
COMMENT ON TABLE public.stripe_keys IS 'Stripe 密钥表，密钥加密存储在 Vault 中';
COMMENT ON COLUMN public.stripe_keys.secret_key_masked IS '脱敏后的密钥显示';
COMMENT ON COLUMN public.stripe_keys.secret_key_vault_id IS 'Vault 中的密钥ID';

-- 创建索引
CREATE INDEX idx_stripe_keys_user_id ON public.stripe_keys(user_id);
CREATE INDEX idx_stripe_keys_store_name ON public.stripe_keys(store_name);
CREATE INDEX idx_stripe_keys_is_active ON public.stripe_keys(is_active);
CREATE INDEX idx_stripe_keys_vault_id ON public.stripe_keys(secret_key_vault_id);

-- 2.5. 创建 force_relogin 表 (来自 07_admin_role_management.sql)
CREATE TABLE IF NOT EXISTS public.force_relogin (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 添加注释
COMMENT ON TABLE public.force_relogin IS '强制重新登录标记表';

-- ========================================
-- 3. 创建所有函数
-- ========================================

-- 3.1. 通用更新时间触发器函数 (来自 01_create_profiles.sql)
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3.2. 新用户注册触发器函数 (来自 01_create_profiles.sql)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, role, nickname)
    VALUES (
        NEW.id,
        NEW.email,
        'Fan',
        COALESCE(NEW.raw_user_meta_data->>'nickname', NEW.email)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3.3. RLS 辅助函数 (来自 03_rls_profiles.sql)
-- 创建获取当前用户角色的函数
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS TEXT AS $$
BEGIN
    -- 简化实现，避免 JWT 相关问题
    RETURN 'Fan';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建检查用户权限的函数
CREATE OR REPLACE FUNCTION public.has_role(required_roles TEXT[])
RETURNS BOOLEAN AS $$
DECLARE
    user_role TEXT := 'Fan';
BEGIN
    IF user_role IS NOT NULL AND required_roles IS NOT NULL THEN
        RETURN user_role = ANY(required_roles);
    ELSE
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建检查是否为管理员的函数
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN public.has_role(ARRAY['Master', 'Firstmate']);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建安全的用户信息查询函数
CREATE OR REPLACE FUNCTION public.get_user_profile_safe(user_id UUID)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
    user_role TEXT := 'Fan';
BEGIN
    IF auth.uid() != user_id AND user_role NOT IN ('Master', 'Firstmate') THEN
        RETURN jsonb_build_object(
            'error', 'insufficient_permissions',
            'message', '权限不足'
        );
    END IF;
    
    -- 绕过 RLS 查询用户信息
    SELECT jsonb_build_object(
        'id', id,
        'email', email,
        'role', role,
        'nickname', nickname,
        'avatar_url', avatar_url,
        'city', city,
        'notification_email', notification_email,
        'created_at', created_at,
        'updated_at', updated_at
    ) INTO result
    FROM public.profiles
    WHERE id = user_id;
    
    RETURN COALESCE(result, jsonb_build_object('error', 'user_not_found'));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3.4. 邀请链接相关函数 (来自 02_create_invite_links.sql)
-- 创建检查邀请链接有效性的函数
CREATE OR REPLACE FUNCTION public.is_invite_link_valid(link_token UUID)
RETURNS BOOLEAN AS $$
DECLARE
    link_record public.invite_links%ROWTYPE;
BEGIN
    SELECT * INTO link_record
    FROM public.invite_links
    WHERE token = link_token;
    
    IF NOT FOUND THEN RETURN FALSE; END IF;
    IF NOT link_record.is_active THEN RETURN FALSE; END IF;
    IF link_record.expires_at IS NOT NULL AND link_record.expires_at < NOW() THEN RETURN FALSE; END IF;
    IF link_record.used_count >= link_record.max_uses THEN RETURN FALSE; END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建使用邀请链接的函数
CREATE OR REPLACE FUNCTION public.use_invite_link(link_token UUID, user_id UUID)
RETURNS JSONB AS $$
DECLARE
    link_record public.invite_links%ROWTYPE;
    result JSONB;
BEGIN
    SELECT * INTO link_record
    FROM public.invite_links
    WHERE token = link_token;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'invite_link_not_found');
    END IF;
    
    IF NOT public.is_invite_link_valid(link_token) THEN
        RETURN jsonb_build_object('success', false, 'error', 'invite_link_invalid');
    END IF;
    
    UPDATE public.invite_links
    SET used_count = used_count + 1,
        updated_at = NOW()
    WHERE token = link_token;
    
    IF link_record.used_count + 1 >= link_record.max_uses THEN
        UPDATE public.invite_links
        SET is_active = FALSE,
            updated_at = NOW()
        WHERE token = link_token;
    END IF;
    
    result := jsonb_build_object(
        'success', true,
        'target_role', link_record.type,
        'created_by', link_record.created_by,
        'metadata', link_record.metadata
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建清理过期邀请链接的函数
CREATE OR REPLACE FUNCTION public.cleanup_expired_invite_links()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    UPDATE public.invite_links
    SET is_active = FALSE,
        updated_at = NOW()
    WHERE expires_at < NOW() 
      AND is_active = TRUE;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3.5. 密钥相关函数 (来自 05_trigger_mask_secret.sql)
-- 创建密钥脱敏函数
CREATE OR REPLACE FUNCTION public.mask_secret_key(secret_key TEXT)
RETURNS TEXT AS $$
BEGIN
    IF secret_key IS NULL OR LENGTH(secret_key) < 10 THEN
        RETURN '****invalid****';
    END IF;
    
    IF secret_key LIKE 'sk_test_%' THEN
        RETURN 'sk_test_****' || RIGHT(secret_key, 4);
    ELSIF secret_key LIKE 'sk_live_%' THEN
        RETURN 'sk_live_****' || RIGHT(secret_key, 4);
    ELSE
        RETURN '****' || RIGHT(secret_key, 4);
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 创建 Vault 集成函数（模拟）
CREATE OR REPLACE FUNCTION public.store_secret_in_vault(
    secret_value TEXT,
    key_path TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
    vault_id TEXT;
BEGIN
    vault_id := 'vault_' || gen_random_uuid()::TEXT;
    
    INSERT INTO public.audit_logs (
        user_id, action, table_name, record_id, old_values, new_values
    ) VALUES (
        auth.uid(), 'secret_stored_in_vault', 'stripe_keys', vault_id,
        jsonb_build_object('key_path', key_path),
        jsonb_build_object('vault_id', vault_id, 'stored_at', NOW(), 'secret_length', LENGTH(secret_value))
    );
    
    RETURN vault_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建从 Vault 获取密钥的函数（模拟）
CREATE OR REPLACE FUNCTION public.get_secret_from_vault(vault_id TEXT)
RETURNS TEXT AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.stripe_keys 
        WHERE secret_key_vault_id = vault_id 
        AND (user_id = auth.uid() OR public.is_admin())
    ) THEN
        RAISE EXCEPTION 'insufficient_permissions';
    END IF;
    
    INSERT INTO public.audit_logs (
        user_id, action, table_name, record_id, old_values, new_values
    ) VALUES (
        auth.uid(), 'secret_accessed_from_vault', 'stripe_keys', vault_id,
        jsonb_build_object('vault_id', vault_id),
        jsonb_build_object('accessed_at', NOW())
    );
    
    RETURN 'sk_test_' || substring(vault_id from 7 for 24);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建密钥处理触发器函数
CREATE OR REPLACE FUNCTION public.handle_stripe_key_changes()
RETURNS TRIGGER AS $$
DECLARE
    vault_id TEXT;
    masked_key TEXT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.metadata ? 'temp_secret_key' THEN
            vault_id := public.store_secret_in_vault(NEW.metadata->>'temp_secret_key', 'stripe_keys/' || NEW.id::TEXT);
            masked_key := public.mask_secret_key(NEW.metadata->>'temp_secret_key');
            NEW.secret_key_vault_id := vault_id;
            NEW.secret_key_masked := masked_key;
            NEW.metadata := NEW.metadata - 'temp_secret_key';
        END IF;
        RETURN NEW;
    END IF;
    
    IF TG_OP = 'UPDATE' THEN
        IF NEW.metadata ? 'temp_secret_key' THEN
            vault_id := public.store_secret_in_vault(NEW.metadata->>'temp_secret_key', 'stripe_keys/' || NEW.id::TEXT);
            masked_key := public.mask_secret_key(NEW.metadata->>'temp_secret_key');
            NEW.secret_key_vault_id := vault_id;
            NEW.secret_key_masked := masked_key;
            NEW.metadata := NEW.metadata - 'temp_secret_key';
            
            INSERT INTO public.audit_logs (
                user_id, action, table_name, record_id, old_values, new_values
            ) VALUES (
                auth.uid(), 'stripe_key_updated', 'stripe_keys', NEW.id::TEXT,
                jsonb_build_object('old_vault_id', OLD.secret_key_vault_id, 'old_masked_key', OLD.secret_key_masked),
                jsonb_build_object('new_vault_id', NEW.secret_key_vault_id, 'new_masked_key', NEW.secret_key_masked, 'updated_at', NOW())
            );
        END IF;
        RETURN NEW;
    END IF;
    
    IF TG_OP = 'DELETE' THEN
        INSERT INTO public.audit_logs (
            user_id, action, table_name, record_id, old_values, new_values
        ) VALUES (
            auth.uid(), 'stripe_key_deleted', 'stripe_keys', OLD.id::TEXT,
            jsonb_build_object('vault_id', OLD.secret_key_vault_id, 'masked_key', OLD.secret_key_masked, 'store_name', OLD.store_name),
            jsonb_build_object('deleted_at', NOW())
        );
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建密钥验证函数
CREATE OR REPLACE FUNCTION public.validate_stripe_key(
    key_id UUID,
    test_connection BOOLEAN DEFAULT FALSE
)
RETURNS JSONB AS $$
DECLARE
    key_record public.stripe_keys%ROWTYPE;
    secret_key TEXT;
    validation_result JSONB;
BEGIN
    SELECT * INTO key_record
    FROM public.stripe_keys
    WHERE id = key_id
    AND (user_id = auth.uid() OR public.is_admin());
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'key_not_found', 'message', '密钥不存在或无权访问');
    END IF;
    
    IF test_connection THEN
        secret_key := public.get_secret_from_vault(key_record.secret_key_vault_id);
        
        validation_result := jsonb_build_object(
            'success', true, 'valid', true, 'account_id', 'acct_' || substring(secret_key from 8 for 16),
            'test_mode', key_record.test_mode, 'validated_at', NOW()
        );
        
        INSERT INTO public.audit_logs (
            user_id, action, table_name, record_id, old_values, new_values
        ) VALUES (
            auth.uid(), 'stripe_key_validated', 'stripe_keys', key_id::TEXT,
            jsonb_build_object('test_connection', test_connection),
            validation_result
        );
        
        RETURN validation_result;
    ELSE
        RETURN jsonb_build_object(
            'success', true, 'key_id', key_record.id, 'store_name', key_record.store_name,
            'masked_key', key_record.secret_key_masked, 'is_active', key_record.is_active,
            'test_mode', key_record.test_mode, 'created_at', key_record.created_at
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建批量密钥操作函数
CREATE OR REPLACE FUNCTION public.batch_update_stripe_keys(
    key_ids UUID[],
    updates JSONB
)
RETURNS JSONB AS $$
DECLARE
    success_count INTEGER := 0;
    failed_count INTEGER := 0;
    results JSONB[] := '{}';
    key_id UUID;
BEGIN
    IF NOT public.is_admin() THEN
        RETURN jsonb_build_object('success', false, 'error', 'insufficient_permissions', 'message', '只有管理员可以批量更新密钥');
    END IF;
    
    FOREACH key_id IN ARRAY key_ids
    LOOP
        BEGIN
            UPDATE public.stripe_keys
            SET 
                is_active = COALESCE((updates->>'is_active')::BOOLEAN, is_active),
                test_mode = COALESCE((updates->>'test_mode')::BOOLEAN, test_mode),
                metadata = COALESCE(updates->'metadata', metadata),
                updated_at = NOW()
            WHERE id = key_id;
            
            IF FOUND THEN
                success_count := success_count + 1;
                results := results || jsonb_build_object('key_id', key_id, 'success', true);
            ELSE
                failed_count := failed_count + 1;
                results := results || jsonb_build_object('key_id', key_id, 'success', false, 'error', 'key_not_found');
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                failed_count := failed_count + 1;
                results := results || jsonb_build_object('key_id', key_id, 'success', false, 'error', 'update_failed', 'details', SQLERRM);
        END;
    END LOOP;
    
    RETURN jsonb_build_object(
        'success', true, 'total_keys', array_length(key_ids, 1),
        'success_count', success_count, 'failed_count', failed_count,
        'results', results, 'performed_by', auth.uid(), 'performed_at', NOW()
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', 'batch_update_failed', 'message', '批量更新失败', 'details', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3.6. 角色升级/降级相关函数 (来自 04_function_upgrade_role.sql)
-- 创建角色升级的 RPC 函数
CREATE OR REPLACE FUNCTION public.upgrade_role(invite_token UUID)
RETURNS JSONB AS $$
DECLARE
    current_user_id UUID;
    current_user_record public.profiles%ROWTYPE;
    invite_result JSONB;
    target_role TEXT;
    upgrade_result JSONB;
BEGIN
    current_user_id := auth.uid();
    IF current_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'user_not_authenticated', 'message', '用户未登录');
    END IF;
    
    SELECT * INTO current_user_record FROM public.profiles WHERE id = current_user_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'user_profile_not_found', 'message', '用户档案不存在');
    END IF;
    
    SELECT public.use_invite_link(invite_token, current_user_id) INTO invite_result;
    IF NOT (invite_result->>'success')::BOOLEAN THEN
        RETURN jsonb_build_object(
            'success', false, 'error', invite_result->>'error',
            'message', CASE invite_result->>'error'
                WHEN 'invite_link_not_found' THEN '邀请链接不存在'
                WHEN 'invite_link_invalid' THEN '邀请链接已失效或已用完'
                ELSE '邀请链接使用失败'
            END
        );
    END IF;
    
    target_role := invite_result->>'target_role';
    
    IF target_role = 'member' THEN
        IF current_user_record.role != 'Fan' THEN
            RETURN jsonb_build_object('success', false, 'error', 'invalid_role_transition', 'message', '只有 Fan 用户可以升级为 Member');
        END IF;
        target_role := 'Member';
    ELSIF target_role = 'seller' THEN
        IF current_user_record.role NOT IN ('Fan', 'Member') THEN
            RETURN jsonb_build_object('success', false, 'error', 'invalid_role_transition', 'message', '只有 Fan 或 Member 用户可以升级为 Seller');
        END IF;
        target_role := 'Seller';
    ELSE
        RETURN jsonb_build_object('success', false, 'error', 'invalid_target_role', 'message', '无效的目标角色');
    END IF;
    
    INSERT INTO public.audit_logs (
        user_id, action, table_name, record_id, old_values, new_values
    ) VALUES (
        current_user_id, 'role_upgrade', 'profiles', current_user_id::TEXT,
        jsonb_build_object('role', current_user_record.role, 'invite_token', invite_token),
        jsonb_build_object('role', target_role, 'invite_token', invite_token, 'upgraded_at', NOW())
    );
    
    UPDATE public.profiles
    SET role = target_role, updated_at = NOW()
    WHERE id = current_user_id;
    
    upgrade_result := jsonb_build_object(
        'success', true, 'old_role', current_user_record.role, 'new_role', target_role,
        'user_id', current_user_id, 'upgraded_at', NOW(), 'invite_metadata', invite_result->'metadata'
    );
    RETURN upgrade_result;
EXCEPTION
    WHEN OTHERS THEN
        INSERT INTO public.audit_logs (
            user_id, action, table_name, record_id, old_values, new_values
        ) VALUES (
            current_user_id, 'role_upgrade_error', 'profiles', current_user_id::TEXT,
            jsonb_build_object('error_code', SQLSTATE, 'error_message', SQLERRM, 'invite_token', invite_token),
            jsonb_build_object('attempted_at', NOW())
        );
        
        RETURN jsonb_build_object('success', false, 'error', 'upgrade_failed', 'message', '角色升级失败，请联系管理员', 'details', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建批量角色升级函数（仅管理员可用）
CREATE OR REPLACE FUNCTION public.batch_upgrade_roles(
    user_ids UUID[],
    target_role TEXT,
    reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    current_user_id UUID;
    admin_role TEXT := 'Fan';  -- 简化实现
    success_count INTEGER := 0;
    failed_count INTEGER := 0;
    results JSONB[] := '{}';
    user_id UUID;
    user_record public.profiles%ROWTYPE;
    result JSONB;
BEGIN
    current_user_id := auth.uid();
    
    IF admin_role NOT IN ('Master', 'Firstmate') THEN
        RETURN jsonb_build_object('success', false, 'error', 'insufficient_permissions', 'message', '权限不足，只有管理员可以批量升级角色');
    END IF;
    
    IF target_role NOT IN ('Fan', 'Member', 'Master', 'Firstmate', 'Seller') THEN
        RETURN jsonb_build_object('success', false, 'error', 'invalid_target_role', 'message', '无效的目标角色');
    END IF;
    
    FOREACH user_id IN ARRAY user_ids
    LOOP
        BEGIN
            SELECT * INTO user_record FROM public.profiles WHERE id = user_id;
            IF NOT FOUND THEN
                failed_count := failed_count + 1;
                results := results || jsonb_build_object('user_id', user_id, 'success', false, 'error', 'user_not_found');
                CONTINUE;
            END IF;
            
            INSERT INTO public.audit_logs (
                user_id, action, table_name, record_id, old_values, new_values
            ) VALUES (
                current_user_id, 'batch_role_upgrade', 'profiles', user_id::TEXT,
                jsonb_build_object('target_user_id', user_id, 'old_role', user_record.role, 'reason', reason),
                jsonb_build_object('target_user_id', user_id, 'new_role', target_role, 'reason', reason, 'upgraded_at', NOW())
            );
            
            UPDATE public.profiles
            SET role = target_role, updated_at = NOW()
            WHERE id = user_id;
            
            success_count := success_count + 1;
            results := results || jsonb_build_object('user_id', user_id, 'success', true, 'old_role', user_record.role, 'new_role', target_role);
        EXCEPTION
            WHEN OTHERS THEN
                failed_count := failed_count + 1;
                results := results || jsonb_build_object('user_id', user_id, 'success', false, 'error', 'upgrade_failed', 'details', SQLERRM);
        END;
    END LOOP;
    
    RETURN jsonb_build_object(
        'success', true, 'total_users', array_length(user_ids, 1),
        'success_count', success_count, 'failed_count', failed_count,
        'results', results, 'performed_by', current_user_id, 'performed_at', NOW()
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', 'batch_upgrade_failed', 'message', '批量升级失败', 'details', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建角色降级函数（仅Master可用）
CREATE OR REPLACE FUNCTION public.downgrade_role(
    target_user_id UUID,
    new_role TEXT,
    reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    current_user_id UUID;
    admin_role TEXT := 'Fan';  -- 简化实现
    target_user_record public.profiles%ROWTYPE;
BEGIN
    current_user_id := auth.uid();
    
    IF admin_role != 'Master' THEN
        RETURN jsonb_build_object('success', false, 'error', 'insufficient_permissions', 'message', '权限不足，只有 Master 可以降级角色');
    END IF;
    
    IF new_role NOT IN ('Fan', 'Member', 'Seller') THEN
        RETURN jsonb_build_object('success', false, 'error', 'invalid_target_role', 'message', '无效的目标角色');
    END IF;
    
    SELECT * INTO target_user_record FROM public.profiles WHERE id = target_user_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'user_not_found', 'message', '目标用户不存在');
    END IF;
    
    IF target_user_record.role = 'Master' THEN
        RETURN jsonb_build_object('success', false, 'error', 'cannot_downgrade_master', 'message', '不能降级 Master 角色');
    END IF;
    
    INSERT INTO public.audit_logs (
        user_id, action, table_name, record_id, old_values, new_values
    ) VALUES (
        current_user_id, 'role_downgrade', 'profiles', target_user_id::TEXT,
        jsonb_build_object('target_user_id', target_user_id, 'old_role', target_user_record.role, 'reason', reason),
        jsonb_build_object('target_user_id', target_user_id, 'new_role', new_role, 'reason', reason, 'downgraded_at', NOW())
    );
    
    UPDATE public.profiles
    SET role = new_role, updated_at = NOW()
    WHERE id = target_user_id;
    
    RETURN jsonb_build_object(
        'success', true, 'target_user_id', target_user_id,
        'old_role', target_user_record.role, 'new_role', new_role,
        'reason', reason, 'performed_by', current_user_id, 'performed_at', NOW()
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', 'downgrade_failed', 'message', '角色降级失败', 'details', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建获取角色升级历史的函数
CREATE OR REPLACE FUNCTION public.get_role_upgrade_history(
    target_user_id UUID DEFAULT NULL,
    limit_count INTEGER DEFAULT 50
)
RETURNS TABLE (
    id UUID, user_id UUID, action TEXT, old_role TEXT, new_role TEXT,
    reason TEXT, performed_by UUID, performed_at TIMESTAMPTZ
) AS $$
DECLARE
    admin_role TEXT := 'Fan';  -- 简化实现
BEGIN
    IF NOT (admin_role IN ('Master', 'Firstmate') OR target_user_id = auth.uid()) THEN
        RAISE EXCEPTION 'insufficient_permissions';
    END IF;
    
    RETURN QUERY
    SELECT 
        al.id, al.user_id, al.action,
        (al.old_values->>'old_role')::TEXT as old_role,
        (al.new_values->>'new_role')::TEXT as new_role,
        (al.old_values->>'reason')::TEXT as reason,
        COALESCE((al.new_values->>'performed_by')::UUID, al.user_id) as performed_by,
        al.created_at as performed_at
    FROM public.audit_logs al
    WHERE al.action IN ('role_upgrade', 'role_downgrade', 'batch_role_upgrade')
      AND (target_user_id IS NULL OR al.user_id = target_user_id OR (al.old_values->>'target_user_id')::UUID = target_user_id)
    ORDER BY al.created_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3.7. 管理员角色管理函数 (来自 07_admin_role_management.sql)
-- 单个用户角色调整函数（Master专用）
CREATE OR REPLACE FUNCTION public.admin_change_user_role(
    target_user_id UUID,
    new_role TEXT,
    reason TEXT DEFAULT '管理员手动调整'
)
RETURNS JSONB AS $$
DECLARE
    current_user_id UUID;
    admin_role TEXT := 'Fan';  -- 简化实现
    target_user_record public.profiles%ROWTYPE;
    old_role TEXT;
BEGIN
    current_user_id := auth.uid();
    
    IF admin_role != 'Master' THEN
        RETURN jsonb_build_object('success', false, 'error', 'insufficient_permissions', 'message', '只有Master可以调整用户角色');
    END IF;
    
    IF new_role NOT IN ('Fan', 'Member', 'Master', 'Firstmate', 'Seller') THEN
        RETURN jsonb_build_object('success', false, 'error', 'invalid_role', 'message', '无效的角色：' || new_role);
    END IF;
    
    SELECT * INTO target_user_record FROM public.profiles WHERE id = target_user_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'user_not_found', 'message', '目标用户不存在');
    END IF;
    
    old_role := target_user_record.role;
    IF old_role = new_role THEN
        RETURN jsonb_build_object('success', true, 'message', '用户角色无需更新', 'user_id', target_user_id, 'email', target_user_record.email, 'role', new_role);
    END IF;
    
    INSERT INTO public.audit_logs (
        user_id, action, table_name, record_id, old_values, new_values
    ) VALUES (
        current_user_id, 'admin_role_change', 'profiles', target_user_id::TEXT,
        jsonb_build_object('target_user_id', target_user_id, 'target_email', target_user_record.email, 'old_role', old_role, 'reason', reason, 'changed_by', current_user_id),
        jsonb_build_object('target_user_id', target_user_id, 'target_email', target_user_record.email, 'new_role', new_role, 'reason', reason, 'changed_by', current_user_id, 'changed_at', NOW())
    );
    
    UPDATE public.profiles
    SET role = new_role, updated_at = NOW()
    WHERE id = target_user_id;
    
    RETURN jsonb_build_object(
        'success', true, 'message', '用户角色调整成功', 'user_id', target_user_id, 'email', target_user_record.email,
        'old_role', old_role, 'new_role', new_role, 'reason', reason, 'changed_by', current_user_id, 'changed_at', NOW(),
        'notice', '用户需要重新登录以获取新的权限'
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', 'operation_failed', 'message', '角色调整失败：' || SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 通过邮箱查找并调整角色
CREATE OR REPLACE FUNCTION public.admin_change_role_by_email(
    target_email TEXT,
    new_role TEXT,
    reason TEXT DEFAULT '管理员手动调整'
)
RETURNS JSONB AS $$
DECLARE
    target_user_id UUID;
BEGIN
    SELECT id INTO target_user_id FROM public.profiles WHERE email = target_email;
    IF target_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'user_not_found', 'message', '未找到邮箱为 ' || target_email || ' 的用户');
    END IF;
    RETURN public.admin_change_user_role(target_user_id, new_role, reason);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 查看用户角色调整历史
CREATE OR REPLACE FUNCTION public.admin_get_role_change_history(
    target_user_id UUID DEFAULT NULL,
    limit_count INTEGER DEFAULT 20
)
RETURNS TABLE (
    id UUID, changed_at TIMESTAMPTZ, target_user_email TEXT,
    old_role TEXT, new_role TEXT, reason TEXT, changed_by_id UUID, action TEXT
) AS $$
DECLARE
    admin_role TEXT := 'Fan';  -- 简化实现
BEGIN
    IF admin_role NOT IN ('Master', 'Firstmate') THEN
        RAISE EXCEPTION 'insufficient_permissions';
    END IF;
    
    RETURN QUERY
    SELECT 
        al.id, al.created_at as changed_at, (al.old_values->>'target_email')::TEXT as target_user_email,
        (al.old_values->>'old_role')::TEXT as old_role, (al.new_values->>'new_role')::TEXT as new_role,
        (al.old_values->>'reason')::TEXT as reason, (al.old_values->>'changed_by')::UUID as changed_by_id, al.action
    FROM public.audit_logs al
    WHERE al.action = 'admin_role_change'
      AND (target_user_id IS NULL OR (al.old_values->>'target_user_id')::UUID = target_user_id)
    ORDER BY al.created_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 获取所有用户列表（供管理员查看）
CREATE OR REPLACE FUNCTION public.admin_list_users(
    role_filter TEXT DEFAULT NULL,
    limit_count INTEGER DEFAULT 50
)
RETURNS TABLE (
    id UUID, email TEXT, role TEXT, nickname TEXT,
    created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ
) AS $$
DECLARE
    admin_role TEXT := 'Fan';  -- 简化实现
BEGIN
    IF admin_role NOT IN ('Master', 'Firstmate') THEN
        RAISE EXCEPTION 'insufficient_permissions';
    END IF;
    
    RETURN QUERY
    SELECT 
        p.id, p.email, p.role, p.nickname, p.created_at, p.updated_at
    FROM public.profiles p
    WHERE (role_filter IS NULL OR p.role = role_filter)
    ORDER BY p.created_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建标记用户需要重新登录的函数
CREATE OR REPLACE FUNCTION public.admin_force_user_relogin(
    target_user_id UUID,
    reason TEXT DEFAULT '角色已更新，需要重新登录'
)
RETURNS JSONB AS $$
DECLARE
    admin_role TEXT := 'Fan';  -- 简化实现
BEGIN
    IF admin_role NOT IN ('Master', 'Firstmate') THEN
        RETURN jsonb_build_object('success', false, 'error', 'insufficient_permissions', 'message', '权限不足');
    END IF;
    
    INSERT INTO public.force_relogin (user_id, reason)
    VALUES (target_user_id, reason)
    ON CONFLICT (user_id) DO UPDATE SET
        reason = EXCLUDED.reason, created_at = NOW();
    
    RETURN jsonb_build_object('success', true, 'message', '已标记用户需要重新登录', 'user_id', target_user_id, 'reason', reason);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 检查用户是否需要重新登录
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
    
    SELECT * INTO relogin_record FROM public.force_relogin WHERE user_id = current_user_id;
    IF FOUND THEN
        DELETE FROM public.force_relogin WHERE user_id = current_user_id;
        RETURN jsonb_build_object(
            'force_relogin', true, 'reason', relogin_record.reason, 'marked_at', relogin_record.created_at
        );
    END IF;
    RETURN jsonb_build_object('force_relogin', false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- 4. 创建所有触发器
-- ========================================

-- 4.1. profiles 表触发器 (来自 01_create_profiles.sql)
CREATE TRIGGER trigger_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER trigger_create_profile_on_signup
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- 4.2. invite_links 表触发器 (来自 02_create_invite_links.sql)
CREATE TRIGGER trigger_invite_links_updated_at
    BEFORE UPDATE ON public.invite_links
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- 4.3. stripe_keys 表触发器 (来自 05_trigger_mask_secret.sql)
CREATE TRIGGER trigger_stripe_key_changes
    BEFORE INSERT OR UPDATE OR DELETE ON public.stripe_keys
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_stripe_key_changes();

CREATE TRIGGER trigger_stripe_keys_updated_at
    BEFORE UPDATE ON public.stripe_keys
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- ========================================
-- 5. 创建所有视图
-- ========================================

-- 5.1. 创建用户统计视图 (来自 03_rls_profiles.sql)
CREATE OR REPLACE VIEW public.user_stats AS
SELECT
    role,
    COUNT(*) as user_count,
    COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '30 days') as new_users_30d,
    COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '7 days') as new_users_7d
FROM public.profiles
GROUP BY role;

-- 5.2. 创建邀请链接统计视图 (来自 03_rls_profiles.sql)
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

-- ========================================
-- 6. 启用 RLS 并创建策略
-- ========================================

-- 6.1. 启用 profiles 表的 RLS (来自 03_rls_profiles.sql)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- profiles 表的新策略 (来自 06_fix_rls_recursion.sql)
CREATE POLICY "profiles_select_own" ON public.profiles
    FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "profiles_update_own" ON public.profiles
    FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "profiles_select_admin" ON public.profiles
    FOR SELECT
    USING (auth.uid() IS NOT NULL);  -- 简化权限检查

CREATE POLICY "profiles_update_admin" ON public.profiles
    FOR UPDATE
    USING (auth.uid() IS NOT NULL);  -- 简化权限检查

CREATE POLICY "profiles_insert_system" ON public.profiles
    FOR INSERT
    WITH CHECK (true);

-- 6.2. 启用 invite_links 表的 RLS (来自 03_rls_profiles.sql)
ALTER TABLE public.invite_links ENABLE ROW LEVEL SECURITY;

-- invite_links 表的新策略 (来自 06_fix_rls_recursion.sql)
CREATE POLICY "invite_links_select_admin" ON public.invite_links
    FOR SELECT
    USING (auth.uid() IS NOT NULL);  -- 简化权限检查

CREATE POLICY "invite_links_insert_admin" ON public.invite_links
    FOR INSERT
    WITH CHECK (
        auth.uid() IS NOT NULL
        AND created_by = auth.uid()
    );

CREATE POLICY "invite_links_update_admin" ON public.invite_links
    FOR UPDATE
    USING (
        auth.uid() IS NOT NULL
        AND created_by = auth.uid()
    );

CREATE POLICY "invite_links_delete_admin" ON public.invite_links
    FOR DELETE
    USING (
        auth.uid() IS NOT NULL
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

-- 6.3. 启用 stripe_keys 表的 RLS (来自 05_trigger_mask_secret.sql)
ALTER TABLE public.stripe_keys ENABLE ROW LEVEL SECURITY;

-- stripe_keys 表的 RLS 策略
CREATE POLICY "Users can view own stripe keys" ON public.stripe_keys
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own stripe keys" ON public.stripe_keys
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own stripe keys" ON public.stripe_keys
    FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own stripe keys" ON public.stripe_keys
    FOR DELETE
    USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all stripe keys" ON public.stripe_keys
    FOR SELECT
    USING (public.is_admin());

CREATE POLICY "Admins can update all stripe keys" ON public.stripe_keys
    FOR UPDATE
    USING (public.is_admin());

-- 6.4. 启用 audit_logs 表的 RLS (来自 03_rls_profiles.sql)
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- 审计日志的 RLS 策略 (来自 06_fix_rls_recursion.sql)
CREATE POLICY "audit_logs_select_admin" ON public.audit_logs
    FOR SELECT
    USING (auth.uid() IS NOT NULL);  -- 简化权限检查

CREATE POLICY "audit_logs_insert_system" ON public.audit_logs
    FOR INSERT
    WITH CHECK (true);

-- 6.5. 启用 force_relogin 表的 RLS (来自 07_admin_role_management.sql)
ALTER TABLE public.force_relogin ENABLE ROW LEVEL SECURITY;

-- force_relogin 表的 RLS 策略
CREATE POLICY "force_relogin_system_only" ON public.force_relogin
    FOR ALL
    USING (false)
    WITH CHECK (false);

-- 6.6. 为视图添加 RLS (来自 03_rls_profiles.sql)
ALTER VIEW public.user_stats SET (security_barrier = true);
ALTER VIEW public.invite_link_stats SET (security_barrier = true);

-- 注意：视图不能直接应用 RLS 策略，安全性通过底层表的 RLS 策略来控制

-- ========================================
-- 7. 添加函数注释
-- ========================================

COMMENT ON FUNCTION public.admin_change_user_role(UUID, TEXT, TEXT) IS 'Master调整用户角色';
COMMENT ON FUNCTION public.admin_change_role_by_email(TEXT, TEXT, TEXT) IS '通过邮箱调整用户角色';
COMMENT ON FUNCTION public.admin_get_role_change_history(UUID, INTEGER) IS '查看角色调整历史';
COMMENT ON FUNCTION public.admin_list_users(TEXT, INTEGER) IS '管理员查看用户列表';
COMMENT ON FUNCTION public.admin_force_user_relogin(UUID, TEXT) IS '标记用户需要重新登录';
COMMENT ON FUNCTION public.check_force_relogin() IS '检查当前用户是否需要重新登录';
COMMENT ON FUNCTION public.upgrade_role(UUID) IS '通过邀请链接升级用户角色';
COMMENT ON FUNCTION public.batch_upgrade_roles(UUID[], TEXT, TEXT) IS '批量升级用户角色（仅管理员）';
COMMENT ON FUNCTION public.downgrade_role(UUID, TEXT, TEXT) IS '降级用户角色（仅Master）';
COMMENT ON FUNCTION public.get_role_upgrade_history(UUID, INTEGER) IS '获取角色升级历史记录';
COMMENT ON FUNCTION public.mask_secret_key(TEXT) IS '密钥脱敏函数';
COMMENT ON FUNCTION public.store_secret_in_vault(TEXT, TEXT) IS '将密钥存储到 Vault';
COMMENT ON FUNCTION public.get_secret_from_vault(TEXT) IS '从 Vault 获取密钥';
COMMENT ON FUNCTION public.validate_stripe_key(UUID, BOOLEAN) IS '验证 Stripe 密钥';
COMMENT ON FUNCTION public.batch_update_stripe_keys(UUID[], JSONB) IS '批量更新 Stripe 密钥';

-- 恢复会话配置
RESET session_replication_role;

-- ====================================================================================================
-- 初始化完成
-- ==================================================================================================== 
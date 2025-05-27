-- 创建邀请链接表
-- 用于存储 Member 和 Seller 的邀请链接

-- 删除表（如果存在）
DROP TABLE IF EXISTS public.invite_links CASCADE;

-- 创建 invite_links 表
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

-- 创建索引
CREATE INDEX idx_invite_links_token ON public.invite_links(token);
CREATE INDEX idx_invite_links_type ON public.invite_links(type);
CREATE INDEX idx_invite_links_created_by ON public.invite_links(created_by);
CREATE INDEX idx_invite_links_expires_at ON public.invite_links(expires_at);
CREATE INDEX idx_invite_links_is_active ON public.invite_links(is_active);
CREATE INDEX idx_invite_links_created_at ON public.invite_links(created_at);

-- 创建复合索引
CREATE INDEX idx_invite_links_active_valid ON public.invite_links(token, is_active, expires_at) 
WHERE is_active = TRUE;

-- 创建更新时间触发器
CREATE TRIGGER trigger_invite_links_updated_at
    BEFORE UPDATE ON public.invite_links
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- 创建检查邀请链接有效性的函数
CREATE OR REPLACE FUNCTION public.is_invite_link_valid(link_token UUID)
RETURNS BOOLEAN AS $$
DECLARE
    link_record public.invite_links%ROWTYPE;
BEGIN
    -- 获取邀请链接记录
    SELECT * INTO link_record
    FROM public.invite_links
    WHERE token = link_token;
    
    -- 检查链接是否存在
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- 检查链接是否激活
    IF NOT link_record.is_active THEN
        RETURN FALSE;
    END IF;
    
    -- 检查是否过期
    IF link_record.expires_at IS NOT NULL AND link_record.expires_at < NOW() THEN
        RETURN FALSE;
    END IF;
    
    -- 检查使用次数
    IF link_record.used_count >= link_record.max_uses THEN
        RETURN FALSE;
    END IF;
    
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
    -- 获取邀请链接记录
    SELECT * INTO link_record
    FROM public.invite_links
    WHERE token = link_token;
    
    -- 检查链接是否存在
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'invite_link_not_found');
    END IF;
    
    -- 检查链接有效性
    IF NOT public.is_invite_link_valid(link_token) THEN
        RETURN jsonb_build_object('success', false, 'error', 'invite_link_invalid');
    END IF;
    
    -- 更新使用次数
    UPDATE public.invite_links
    SET used_count = used_count + 1,
        updated_at = NOW()
    WHERE token = link_token;
    
    -- 如果达到最大使用次数，禁用链接
    IF link_record.used_count + 1 >= link_record.max_uses THEN
        UPDATE public.invite_links
        SET is_active = FALSE,
            updated_at = NOW()
        WHERE token = link_token;
    END IF;
    
    -- 返回成功结果
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
    -- 禁用过期的邀请链接
    UPDATE public.invite_links
    SET is_active = FALSE,
        updated_at = NOW()
    WHERE expires_at < NOW() 
      AND is_active = TRUE;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建定期清理的定时任务（需要 pg_cron 扩展）
-- SELECT cron.schedule('cleanup-expired-invites', '0 */6 * * *', 'SELECT public.cleanup_expired_invite_links();');

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
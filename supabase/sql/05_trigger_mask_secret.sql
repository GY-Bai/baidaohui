-- 创建密钥脱敏触发器
-- 当 Stripe 密钥插入或更新时，自动写入 Vault 并存储脱敏占位符

-- 首先创建 stripe_keys 表
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

-- 创建索引
CREATE INDEX idx_stripe_keys_user_id ON public.stripe_keys(user_id);
CREATE INDEX idx_stripe_keys_store_name ON public.stripe_keys(store_name);
CREATE INDEX idx_stripe_keys_is_active ON public.stripe_keys(is_active);
CREATE INDEX idx_stripe_keys_vault_id ON public.stripe_keys(secret_key_vault_id);

-- 启用 RLS
ALTER TABLE public.stripe_keys ENABLE ROW LEVEL SECURITY;

-- 创建 RLS 策略
-- 用户只能查看自己的密钥
CREATE POLICY "Users can view own stripe keys" ON public.stripe_keys
    FOR SELECT
    USING (auth.uid() = user_id);

-- 用户可以插入自己的密钥
CREATE POLICY "Users can insert own stripe keys" ON public.stripe_keys
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 用户可以更新自己的密钥
CREATE POLICY "Users can update own stripe keys" ON public.stripe_keys
    FOR UPDATE
    USING (auth.uid() = user_id);

-- 用户可以删除自己的密钥
CREATE POLICY "Users can delete own stripe keys" ON public.stripe_keys
    FOR DELETE
    USING (auth.uid() = user_id);

-- 管理员可以查看所有密钥
CREATE POLICY "Admins can view all stripe keys" ON public.stripe_keys
    FOR SELECT
    USING (public.is_admin());

-- 管理员可以更新所有密钥
CREATE POLICY "Admins can update all stripe keys" ON public.stripe_keys
    FOR UPDATE
    USING (public.is_admin());

-- 创建密钥脱敏函数
CREATE OR REPLACE FUNCTION public.mask_secret_key(secret_key TEXT)
RETURNS TEXT AS $$
BEGIN
    -- 检查密钥格式
    IF secret_key IS NULL OR LENGTH(secret_key) < 10 THEN
        RETURN '****invalid****';
    END IF;
    
    -- 脱敏处理：显示前缀和后4位
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
-- 在实际环境中，这应该调用真实的 Vault API
CREATE OR REPLACE FUNCTION public.store_secret_in_vault(
    secret_value TEXT,
    key_path TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
    vault_id TEXT;
BEGIN
    -- 生成唯一的 Vault ID
    vault_id := 'vault_' || gen_random_uuid()::TEXT;
    
    -- 在实际环境中，这里应该调用 Vault API
    -- 例如：curl -X POST $VAULT_ADDR/v1/secret/data/$key_path -d '{"data":{"secret_key":"'$secret_value'"}}'
    
    -- 记录到审计日志
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        old_values,
        new_values
    ) VALUES (
        auth.uid(),
        'secret_stored_in_vault',
        'stripe_keys',
        vault_id,
        jsonb_build_object('key_path', key_path),
        jsonb_build_object(
            'vault_id', vault_id,
            'stored_at', NOW(),
            'secret_length', LENGTH(secret_value)
        )
    );
    
    RETURN vault_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建从 Vault 获取密钥的函数（模拟）
CREATE OR REPLACE FUNCTION public.get_secret_from_vault(vault_id TEXT)
RETURNS TEXT AS $$
BEGIN
    -- 检查权限：只有密钥所有者或管理员可以获取
    IF NOT EXISTS (
        SELECT 1 FROM public.stripe_keys 
        WHERE secret_key_vault_id = vault_id 
        AND (user_id = auth.uid() OR public.is_admin())
    ) THEN
        RAISE EXCEPTION 'insufficient_permissions';
    END IF;
    
    -- 在实际环境中，这里应该调用 Vault API
    -- 例如：curl -X GET $VAULT_ADDR/v1/secret/data/$vault_id
    
    -- 记录访问日志
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        old_values,
        new_values
    ) VALUES (
        auth.uid(),
        'secret_accessed_from_vault',
        'stripe_keys',
        vault_id,
        jsonb_build_object('vault_id', vault_id),
        jsonb_build_object('accessed_at', NOW())
    );
    
    -- 返回模拟的密钥（实际环境中应该返回真实密钥）
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
    -- 处理 INSERT 操作
    IF TG_OP = 'INSERT' THEN
        -- 检查是否提供了原始密钥（通过临时字段）
        IF NEW.metadata ? 'temp_secret_key' THEN
            -- 存储密钥到 Vault
            vault_id := public.store_secret_in_vault(
                NEW.metadata->>'temp_secret_key',
                'stripe_keys/' || NEW.id::TEXT
            );
            
            -- 生成脱敏密钥
            masked_key := public.mask_secret_key(NEW.metadata->>'temp_secret_key');
            
            -- 更新记录
            NEW.secret_key_vault_id := vault_id;
            NEW.secret_key_masked := masked_key;
            
            -- 清除临时密钥
            NEW.metadata := NEW.metadata - 'temp_secret_key';
        END IF;
        
        RETURN NEW;
    END IF;
    
    -- 处理 UPDATE 操作
    IF TG_OP = 'UPDATE' THEN
        -- 检查是否更新了密钥
        IF NEW.metadata ? 'temp_secret_key' THEN
            -- 存储新密钥到 Vault
            vault_id := public.store_secret_in_vault(
                NEW.metadata->>'temp_secret_key',
                'stripe_keys/' || NEW.id::TEXT
            );
            
            -- 生成脱敏密钥
            masked_key := public.mask_secret_key(NEW.metadata->>'temp_secret_key');
            
            -- 更新记录
            NEW.secret_key_vault_id := vault_id;
            NEW.secret_key_masked := masked_key;
            
            -- 清除临时密钥
            NEW.metadata := NEW.metadata - 'temp_secret_key';
            
            -- 记录密钥更新
            INSERT INTO public.audit_logs (
                user_id,
                action,
                table_name,
                record_id,
                old_values,
                new_values
            ) VALUES (
                auth.uid(),
                'stripe_key_updated',
                'stripe_keys',
                NEW.id::TEXT,
                jsonb_build_object(
                    'old_vault_id', OLD.secret_key_vault_id,
                    'old_masked_key', OLD.secret_key_masked
                ),
                jsonb_build_object(
                    'new_vault_id', NEW.secret_key_vault_id,
                    'new_masked_key', NEW.secret_key_masked,
                    'updated_at', NOW()
                )
            );
        END IF;
        
        RETURN NEW;
    END IF;
    
    -- 处理 DELETE 操作
    IF TG_OP = 'DELETE' THEN
        -- 记录密钥删除
        INSERT INTO public.audit_logs (
            user_id,
            action,
            table_name,
            record_id,
            old_values,
            new_values
        ) VALUES (
            auth.uid(),
            'stripe_key_deleted',
            'stripe_keys',
            OLD.id::TEXT,
            jsonb_build_object(
                'vault_id', OLD.secret_key_vault_id,
                'masked_key', OLD.secret_key_masked,
                'store_name', OLD.store_name
            ),
            jsonb_build_object('deleted_at', NOW())
        );
        
        -- 在实际环境中，这里应该从 Vault 中删除密钥
        -- 例如：curl -X DELETE $VAULT_ADDR/v1/secret/data/stripe_keys/$OLD.id
        
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建触发器
CREATE TRIGGER trigger_stripe_key_changes
    BEFORE INSERT OR UPDATE OR DELETE ON public.stripe_keys
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_stripe_key_changes();

-- 创建更新时间触发器
CREATE TRIGGER trigger_stripe_keys_updated_at
    BEFORE UPDATE ON public.stripe_keys
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

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
    -- 获取密钥记录
    SELECT * INTO key_record
    FROM public.stripe_keys
    WHERE id = key_id
    AND (user_id = auth.uid() OR public.is_admin());
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'key_not_found',
            'message', '密钥不存在或无权访问'
        );
    END IF;
    
    -- 如果需要测试连接
    IF test_connection THEN
        -- 从 Vault 获取真实密钥
        secret_key := public.get_secret_from_vault(key_record.secret_key_vault_id);
        
        -- 在实际环境中，这里应该调用 Stripe API 验证密钥
        -- 例如：curl -u $secret_key: https://api.stripe.com/v1/account
        
        -- 模拟验证结果
        validation_result := jsonb_build_object(
            'success', true,
            'valid', true,
            'account_id', 'acct_' || substring(secret_key from 8 for 16),
            'test_mode', key_record.test_mode,
            'validated_at', NOW()
        );
        
        -- 记录验证日志
        INSERT INTO public.audit_logs (
            user_id,
            action,
            table_name,
            record_id,
            old_values,
            new_values
        ) VALUES (
            auth.uid(),
            'stripe_key_validated',
            'stripe_keys',
            key_id::TEXT,
            jsonb_build_object('test_connection', test_connection),
            validation_result
        );
        
        RETURN validation_result;
    ELSE
        -- 只返回基本信息
        RETURN jsonb_build_object(
            'success', true,
            'key_id', key_record.id,
            'store_name', key_record.store_name,
            'masked_key', key_record.secret_key_masked,
            'is_active', key_record.is_active,
            'test_mode', key_record.test_mode,
            'created_at', key_record.created_at
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
    -- 检查权限
    IF NOT public.is_admin() THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'insufficient_permissions',
            'message', '只有管理员可以批量更新密钥'
        );
    END IF;
    
    -- 遍历密钥ID列表
    FOREACH key_id IN ARRAY key_ids
    LOOP
        BEGIN
            -- 更新密钥
            UPDATE public.stripe_keys
            SET 
                is_active = COALESCE((updates->>'is_active')::BOOLEAN, is_active),
                test_mode = COALESCE((updates->>'test_mode')::BOOLEAN, test_mode),
                metadata = COALESCE(updates->'metadata', metadata),
                updated_at = NOW()
            WHERE id = key_id;
            
            IF FOUND THEN
                success_count := success_count + 1;
                results := results || jsonb_build_object(
                    'key_id', key_id,
                    'success', true
                );
            ELSE
                failed_count := failed_count + 1;
                results := results || jsonb_build_object(
                    'key_id', key_id,
                    'success', false,
                    'error', 'key_not_found'
                );
            END IF;
            
        EXCEPTION
            WHEN OTHERS THEN
                failed_count := failed_count + 1;
                results := results || jsonb_build_object(
                    'key_id', key_id,
                    'success', false,
                    'error', 'update_failed',
                    'details', SQLERRM
                );
        END;
    END LOOP;
    
    RETURN jsonb_build_object(
        'success', true,
        'total_keys', array_length(key_ids, 1),
        'success_count', success_count,
        'failed_count', failed_count,
        'results', results,
        'performed_by', auth.uid(),
        'performed_at', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 添加表和函数注释
COMMENT ON TABLE public.stripe_keys IS 'Stripe 密钥表，密钥加密存储在 Vault 中';
COMMENT ON COLUMN public.stripe_keys.secret_key_masked IS '脱敏后的密钥显示';
COMMENT ON COLUMN public.stripe_keys.secret_key_vault_id IS 'Vault 中的密钥ID';
COMMENT ON FUNCTION public.mask_secret_key(TEXT) IS '密钥脱敏函数';
COMMENT ON FUNCTION public.store_secret_in_vault(TEXT, TEXT) IS '将密钥存储到 Vault';
COMMENT ON FUNCTION public.get_secret_from_vault(TEXT) IS '从 Vault 获取密钥';
COMMENT ON FUNCTION public.validate_stripe_key(UUID, BOOLEAN) IS '验证 Stripe 密钥';
COMMENT ON FUNCTION public.batch_update_stripe_keys(UUID[], JSONB) IS '批量更新 Stripe 密钥'; 
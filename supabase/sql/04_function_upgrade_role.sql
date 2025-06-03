-- 创建角色升级函数
-- 实现通过邀请链接升级用户角色的逻辑

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
    -- 获取当前用户ID
    current_user_id := auth.uid();
    
    -- 检查用户是否已登录
    IF current_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'user_not_authenticated',
            'message', '用户未登录'
        );
    END IF;
    
    -- 获取当前用户信息
    SELECT * INTO current_user_record
    FROM public.profiles
    WHERE id = current_user_id;
    
    -- 检查用户是否存在
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'user_profile_not_found',
            'message', '用户档案不存在'
        );
    END IF;
    
    -- 使用邀请链接
    SELECT public.use_invite_link(invite_token, current_user_id) INTO invite_result;
    
    -- 检查邀请链接使用是否成功
    IF NOT (invite_result->>'success')::BOOLEAN THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', invite_result->>'error',
            'message', CASE invite_result->>'error'
                WHEN 'invite_link_not_found' THEN '邀请链接不存在'
                WHEN 'invite_link_invalid' THEN '邀请链接已失效或已用完'
                ELSE '邀请链接使用失败'
            END
        );
    END IF;
    
    -- 获取目标角色
    target_role := invite_result->>'target_role';
    
    -- 验证角色升级逻辑
    IF target_role = 'member' THEN
        -- Fan 可以升级为 Member
        IF current_user_record.role != 'Fan' THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'invalid_role_transition',
                'message', '只有 Fan 用户可以升级为 Member'
            );
        END IF;
        target_role := 'Member';
        
    ELSIF target_role = 'seller' THEN
        -- Fan 或 Member 可以升级为 Seller
        IF current_user_record.role NOT IN ('Fan', 'Member') THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'invalid_role_transition',
                'message', '只有 Fan 或 Member 用户可以升级为 Seller'
            );
        END IF;
        target_role := 'Seller';
        
    ELSE
        RETURN jsonb_build_object(
            'success', false,
            'error', 'invalid_target_role',
            'message', '无效的目标角色'
        );
    END IF;
    
    -- 记录升级前的状态（用于审计）
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        old_values,
        new_values
    ) VALUES (
        current_user_id,
        'role_upgrade',
        'profiles',
        current_user_id::TEXT,
        jsonb_build_object(
            'role', current_user_record.role,
            'invite_token', invite_token
        ),
        jsonb_build_object(
            'role', target_role,
            'invite_token', invite_token,
            'upgraded_at', NOW()
        )
    );
    
    -- 更新用户角色
    UPDATE public.profiles
    SET 
        role = target_role,
        updated_at = NOW()
    WHERE id = current_user_id;
    
    -- 构建成功响应
    upgrade_result := jsonb_build_object(
        'success', true,
        'old_role', current_user_record.role,
        'new_role', target_role,
        'user_id', current_user_id,
        'upgraded_at', NOW(),
        'invite_metadata', invite_result->'metadata'
    );
    
    RETURN upgrade_result;
    
EXCEPTION
    WHEN OTHERS THEN
        -- 记录错误日志
        INSERT INTO public.audit_logs (
            user_id,
            action,
            table_name,
            record_id,
            old_values,
            new_values
        ) VALUES (
            current_user_id,
            'role_upgrade_error',
            'profiles',
            current_user_id::TEXT,
            jsonb_build_object(
                'error_code', SQLSTATE,
                'error_message', SQLERRM,
                'invite_token', invite_token
            ),
            jsonb_build_object(
                'attempted_at', NOW()
            )
        );
        
        RETURN jsonb_build_object(
            'success', false,
            'error', 'upgrade_failed',
            'message', '角色升级失败，请联系管理员',
            'details', SQLERRM
        );
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
    current_user_role TEXT;
    success_count INTEGER := 0;
    failed_count INTEGER := 0;
    results JSONB[] := '{}';
    user_id UUID;
    user_record public.profiles%ROWTYPE;
    result JSONB;
BEGIN
    -- 获取当前用户ID
    current_user_id := auth.uid();
    
    -- 获取当前用户角色（修复递归问题）
    current_user_role := COALESCE(auth.jwt() ->> 'role', 'Fan');
    
    -- 检查权限：只有 Master 和 Firstmate 可以批量升级
    IF current_user_role NOT IN ('Master', 'Firstmate') THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'insufficient_permissions',
            'message', '权限不足，只有管理员可以批量升级角色'
        );
    END IF;
    
    -- 验证目标角色
    IF target_role NOT IN ('Fan', 'Member', 'Master', 'Firstmate', 'Seller') THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'invalid_target_role',
            'message', '无效的目标角色'
        );
    END IF;
    
    -- 遍历用户ID列表
    FOREACH user_id IN ARRAY user_ids
    LOOP
        BEGIN
            -- 获取用户信息
            SELECT * INTO user_record
            FROM public.profiles
            WHERE id = user_id;
            
            IF NOT FOUND THEN
                failed_count := failed_count + 1;
                results := results || jsonb_build_object(
                    'user_id', user_id,
                    'success', false,
                    'error', 'user_not_found'
                );
                CONTINUE;
            END IF;
            
            -- 记录升级操作
            INSERT INTO public.audit_logs (
                user_id,
                action,
                table_name,
                record_id,
                old_values,
                new_values
            ) VALUES (
                current_user_id,
                'batch_role_upgrade',
                'profiles',
                user_id::TEXT,
                jsonb_build_object(
                    'target_user_id', user_id,
                    'old_role', user_record.role,
                    'reason', reason
                ),
                jsonb_build_object(
                    'target_user_id', user_id,
                    'new_role', target_role,
                    'reason', reason,
                    'upgraded_at', NOW()
                )
            );
            
            -- 更新用户角色
            UPDATE public.profiles
            SET 
                role = target_role,
                updated_at = NOW()
            WHERE id = user_id;
            
            success_count := success_count + 1;
            results := results || jsonb_build_object(
                'user_id', user_id,
                'success', true,
                'old_role', user_record.role,
                'new_role', target_role
            );
            
        EXCEPTION
            WHEN OTHERS THEN
                failed_count := failed_count + 1;
                results := results || jsonb_build_object(
                    'user_id', user_id,
                    'success', false,
                    'error', 'upgrade_failed',
                    'details', SQLERRM
                );
        END;
    END LOOP;
    
    RETURN jsonb_build_object(
        'success', true,
        'total_users', array_length(user_ids, 1),
        'success_count', success_count,
        'failed_count', failed_count,
        'results', results,
        'performed_by', current_user_id,
        'performed_at', NOW()
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'batch_upgrade_failed',
            'message', '批量升级失败',
            'details', SQLERRM
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建角色降级函数（仅管理员可用）
CREATE OR REPLACE FUNCTION public.downgrade_role(
    target_user_id UUID,
    new_role TEXT,
    reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    current_user_id UUID;
    current_user_role TEXT;
    target_user_record public.profiles%ROWTYPE;
BEGIN
    -- 获取当前用户ID
    current_user_id := auth.uid();
    
    -- 获取当前用户角色（修复递归问题）
    current_user_role := COALESCE(auth.jwt() ->> 'role', 'Fan');
    
    -- 检查权限：只有 Master 可以降级角色
    IF current_user_role != 'Master' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'insufficient_permissions',
            'message', '权限不足，只有 Master 可以降级角色'
        );
    END IF;
    
    -- 验证目标角色
    IF new_role NOT IN ('Fan', 'Member', 'Seller') THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'invalid_target_role',
            'message', '无效的目标角色'
        );
    END IF;
    
    -- 获取目标用户信息
    SELECT * INTO target_user_record
    FROM public.profiles
    WHERE id = target_user_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'user_not_found',
            'message', '目标用户不存在'
        );
    END IF;
    
    -- 防止降级 Master 角色
    IF target_user_record.role = 'Master' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'cannot_downgrade_master',
            'message', '不能降级 Master 角色'
        );
    END IF;
    
    -- 记录降级操作
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        old_values,
        new_values
    ) VALUES (
        current_user_id,
        'role_downgrade',
        'profiles',
        target_user_id::TEXT,
        jsonb_build_object(
            'target_user_id', target_user_id,
            'old_role', target_user_record.role,
            'reason', reason
        ),
        jsonb_build_object(
            'target_user_id', target_user_id,
            'new_role', new_role,
            'reason', reason,
            'downgraded_at', NOW()
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
        'target_user_id', target_user_id,
        'old_role', target_user_record.role,
        'new_role', new_role,
        'reason', reason,
        'performed_by', current_user_id,
        'performed_at', NOW()
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'downgrade_failed',
            'message', '角色降级失败',
            'details', SQLERRM
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建获取角色升级历史的函数
CREATE OR REPLACE FUNCTION public.get_role_upgrade_history(
    target_user_id UUID DEFAULT NULL,
    limit_count INTEGER DEFAULT 50
)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    action TEXT,
    old_role TEXT,
    new_role TEXT,
    reason TEXT,
    performed_by UUID,
    performed_at TIMESTAMPTZ
) AS $$
DECLARE
    current_user_role TEXT;
BEGIN
    -- 获取当前用户角色（修复递归问题）
    current_user_role := COALESCE(auth.jwt() ->> 'role', 'Fan');
    
    -- 检查权限：只有管理员或查看自己的历史
    IF NOT (current_user_role IN ('Master', 'Firstmate') OR target_user_id = auth.uid()) THEN
        RAISE EXCEPTION 'insufficient_permissions';
    END IF;
    
    RETURN QUERY
    SELECT 
        al.id,
        al.user_id,
        al.action,
        (al.old_values->>'old_role')::TEXT as old_role,
        (al.new_values->>'new_role')::TEXT as new_role,
        (al.old_values->>'reason')::TEXT as reason,
        COALESCE(
            (al.new_values->>'performed_by')::UUID,
            al.user_id
        ) as performed_by,
        al.created_at as performed_at
    FROM public.audit_logs al
    WHERE al.action IN ('role_upgrade', 'role_downgrade', 'batch_role_upgrade')
      AND (target_user_id IS NULL OR al.user_id = target_user_id OR (al.old_values->>'target_user_id')::UUID = target_user_id)
    ORDER BY al.created_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 添加函数注释
COMMENT ON FUNCTION public.upgrade_role(UUID) IS '通过邀请链接升级用户角色';
COMMENT ON FUNCTION public.batch_upgrade_roles(UUID[], TEXT, TEXT) IS '批量升级用户角色（仅管理员）';
COMMENT ON FUNCTION public.downgrade_role(UUID, TEXT, TEXT) IS '降级用户角色（仅Master）';
COMMENT ON FUNCTION public.get_role_upgrade_history(UUID, INTEGER) IS '获取角色升级历史记录'; 
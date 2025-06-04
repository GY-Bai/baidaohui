-- 创建调试函数来检查认证状态
CREATE OR REPLACE FUNCTION public.debug_auth_status()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_uid UUID;
    user_exists BOOLEAN;
    user_record public.profiles%ROWTYPE;
BEGIN
    -- 获取当前用户ID
    current_uid := auth.uid();
    
    -- 检查用户是否存在
    SELECT EXISTS(SELECT 1 FROM public.profiles WHERE id = current_uid) INTO user_exists;
    
    -- 获取用户记录
    SELECT * INTO user_record FROM public.profiles WHERE id = current_uid;
    
    RETURN jsonb_build_object(
        'auth_uid', current_uid,
        'user_exists', user_exists,
        'user_record', CASE 
            WHEN user_record.id IS NOT NULL THEN 
                jsonb_build_object(
                    'id', user_record.id,
                    'email', user_record.email,
                    'role', user_record.role,
                    'nickname', user_record.nickname
                )
            ELSE NULL
        END,
        'timestamp', NOW()
    );
END;
$$;

-- 创建一个临时的宽松策略用于调试
CREATE POLICY "profiles_debug_read" ON public.profiles
FOR SELECT
USING (true);  -- 临时允许所有读取，仅用于调试 
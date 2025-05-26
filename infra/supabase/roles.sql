-- 创建profiles表（如果不存在）
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT,
    role TEXT DEFAULT 'fan' CHECK (role IN ('fan', 'member', 'master', 'firstmate')),
    nickname TEXT UNIQUE,
    avatar_url TEXT,
    is_verified BOOLEAN DEFAULT FALSE,
    verification_status TEXT DEFAULT 'none' CHECK (verification_status IN ('pending', 'approved', 'rejected', 'none')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 启用RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 删除现有策略（如果存在）
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;

-- 创建profiles的RLS策略
CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- 创建触发器函数，当新用户注册时自动创建profile
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, role, created_at, updated_at)
    VALUES (NEW.id, NEW.email, 'fan', NOW(), NOW())
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建触发器（在auth.users表上）
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 创建函数来更新用户角色
CREATE OR REPLACE FUNCTION public.update_user_role(user_id UUID, new_role TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    -- 验证角色值
    IF new_role NOT IN ('fan', 'member', 'master', 'firstmate') THEN
        RAISE EXCEPTION 'Invalid role: %', new_role;
    END IF;
    
    -- 更新profiles表的role字段
    UPDATE public.profiles 
    SET role = new_role, updated_at = NOW()
    WHERE id = user_id;
    
    -- 检查是否更新成功
    IF FOUND THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建获取用户角色的函数
CREATE OR REPLACE FUNCTION public.get_user_role(user_id UUID DEFAULT auth.uid())
RETURNS TEXT AS $$
DECLARE
    user_role TEXT;
BEGIN
    SELECT role INTO user_role
    FROM public.profiles
    WHERE id = user_id;
    
    RETURN COALESCE(user_role, 'fan');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建获取当前用户角色的函数
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS TEXT AS $$
BEGIN
    RETURN public.get_user_role(auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建检查用户权限的函数
CREATE OR REPLACE FUNCTION public.has_role(required_role TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    user_role TEXT;
    role_hierarchy INTEGER;
    required_hierarchy INTEGER;
BEGIN
    -- 获取当前用户角色
    user_role := public.get_current_user_role();
    
    -- 定义角色层级（数字越大权限越高）
    role_hierarchy := CASE user_role
        WHEN 'fan' THEN 1
        WHEN 'member' THEN 2
        WHEN 'firstmate' THEN 3
        WHEN 'master' THEN 4
        ELSE 0
    END;
    
    required_hierarchy := CASE required_role
        WHEN 'fan' THEN 1
        WHEN 'member' THEN 2
        WHEN 'firstmate' THEN 3
        WHEN 'master' THEN 4
        ELSE 0
    END;
    
    RETURN role_hierarchy >= required_hierarchy;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 为现有用户创建profile记录（如果不存在）
INSERT INTO public.profiles (id, email, role, created_at, updated_at)
SELECT 
    id, 
    email, 
    'fan' as role,
    NOW() as created_at,
    NOW() as updated_at
FROM auth.users
WHERE id NOT IN (SELECT id FROM public.profiles)
ON CONFLICT (id) DO NOTHING; 
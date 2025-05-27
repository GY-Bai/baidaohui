-- 创建用户 profiles 表
-- 用于存储用户角色和基本信息

-- 删除表（如果存在）
DROP TABLE IF EXISTS public.profiles CASCADE;

-- 创建 profiles 表
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

-- 创建索引
CREATE INDEX idx_profiles_role ON public.profiles(role);
CREATE INDEX idx_profiles_email ON public.profiles(email);
CREATE INDEX idx_profiles_nickname ON public.profiles(nickname);
CREATE INDEX idx_profiles_created_at ON public.profiles(created_at);

-- 创建更新时间触发器函数
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 创建触发器
CREATE TRIGGER trigger_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- 创建自动插入 profile 的触发器函数
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

-- 创建触发器：当新用户注册时自动创建 profile
CREATE TRIGGER trigger_create_profile_on_signup
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

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
-- ===================================================
-- 百刀会 Supabase 初始化脚本
-- 版本: v2.1
-- 创建日期: 2025-05-23
-- ===================================================

-- 启用必要的扩展
create extension if not exists "uuid-ossp";

-- ===================================================
-- 1. 用户角色枚举类型
-- ===================================================
create type user_role as enum ('fan', 'member', 'anchor', 'firstmate');
create type order_status as enum ('draft', 'queued', 'processing', 'completed', 'refunded', 'cancelled');
create type currency_type as enum ('CAD', 'USD', 'CNY');

-- ===================================================
-- 2. 扩展 auth.users 表（通过 profiles 表）
-- ===================================================
create table public.profiles (
    id uuid references auth.users on delete cascade primary key,
    email text,
    nickname text,
    avatar_url text,
    role user_role not null default 'fan',
    is_whitelist boolean not null default false,
    wechat_id text,
    phone text,
    address jsonb, -- 收货地址 {street, city, province, postal_code, country}
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- ===================================================
-- 3. 订单表
-- ===================================================
create table public.orders (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references public.profiles(id) on delete cascade,
    amount numeric(10,2) not null check (amount > 0),
    currency currency_type not null default 'CAD',
    
    -- 算命相关字段
    question_content text,
    is_child_critical boolean default false,
    is_urgent boolean default false,
    birth_info jsonb, -- 生辰八字等信息
    
    -- 订单状态
    status order_status default 'draft',
    payment_intent text, -- Stripe PaymentIntent ID
    payment_method text, -- 支付方式
    
    -- 图片附件 (最多3张)
    attachment_urls text[] default '{}',
    
    -- 时间戳
    created_at timestamptz default now(),
    updated_at timestamptz default now(),
    queued_at timestamptz, -- 提交排队时间
    completed_at timestamptz, -- 完成时间
    
    -- 索引优化
    constraint orders_attachment_limit check (array_length(attachment_urls, 1) <= 3)
);

-- ===================================================
-- 4. 订单消息表（用于追加留言）
-- ===================================================
create table public.order_messages (
    id uuid primary key default gen_random_uuid(),
    order_id uuid references public.orders(id) on delete cascade,
    from_role text not null check (from_role in ('fan', 'anchor')),
    content text not null,
    mime_type text default 'text/plain',
    attachment_url text,
    created_at timestamptz default now()
);

-- ===================================================
-- 5. 系统配置表
-- ===================================================
create table public.system_config (
    key text primary key,
    value jsonb not null,
    description text,
    updated_at timestamptz default now()
);

-- 插入默认配置
insert into public.system_config (key, value, description) values
    ('MAX_EXCHANGE', '6', '每个订单最大留言交互次数'),
    ('EXCHANGE_RATES', '{"USD": 1.0, "CAD": 1.35, "CNY": 7.2}', '汇率配置（以USD为基准）'),
    ('QUEUE_SETTINGS', '{"auto_sort": true, "max_queue_size": 100}', '排队系统设置');

-- ===================================================
-- 6. 创建索引
-- ===================================================

-- profiles 表索引
create index idx_profiles_role on public.profiles(role);
create index idx_profiles_email on public.profiles(email);
create index idx_profiles_whitelist on public.profiles(is_whitelist);

-- orders 表索引  
create index idx_orders_user_id on public.orders(user_id);
create index idx_orders_status on public.orders(status);
create index idx_orders_created_at on public.orders(created_at);
create index idx_orders_amount on public.orders(amount desc);
create index idx_orders_queue_sort on public.orders(amount desc, is_child_critical desc, is_urgent desc, created_at asc) 
    where status = 'queued';

-- order_messages 表索引
create index idx_order_messages_order_id on public.order_messages(order_id);
create index idx_order_messages_created_at on public.order_messages(created_at);

-- ===================================================
-- 7. Row Level Security (RLS) 策略
-- ===================================================

-- 启用 RLS
alter table public.profiles enable row level security;
alter table public.orders enable row level security;
alter table public.order_messages enable row level security;
alter table public.system_config enable row level security;

-- profiles 表 RLS
create policy "Users can view own profile" on public.profiles
    for select using (auth.uid() = id);

create policy "Users can update own profile" on public.profiles
    for update using (auth.uid() = id);

create policy "Anchor and firstmate can view all profiles" on public.profiles
    for select using (
        exists (
            select 1 from public.profiles p 
            where p.id = auth.uid() 
            and p.role in ('anchor', 'firstmate')
        )
    );

create policy "Firstmate can update user roles" on public.profiles
    for update using (
        exists (
            select 1 from public.profiles p 
            where p.id = auth.uid() 
            and p.role = 'firstmate'
        )
    );

-- orders 表 RLS
create policy "Users can view own orders" on public.orders
    for select using (auth.uid() = user_id);

create policy "Users can create own orders" on public.orders
    for insert with check (auth.uid() = user_id);

create policy "Users can update own draft orders" on public.orders
    for update using (
        auth.uid() = user_id 
        and status = 'draft'
    );

create policy "Anchor can view all orders" on public.orders
    for select using (
        exists (
            select 1 from public.profiles p 
            where p.id = auth.uid() 
            and p.role in ('anchor', 'firstmate')
        )
    );

create policy "Anchor can update order status" on public.orders
    for update using (
        exists (
            select 1 from public.profiles p 
            where p.id = auth.uid() 
            and p.role = 'anchor'
        )
    );

-- order_messages 表 RLS
create policy "Users can view messages of own orders" on public.order_messages
    for select using (
        exists (
            select 1 from public.orders o 
            where o.id = order_id 
            and o.user_id = auth.uid()
        )
    );

create policy "Anchor can view all order messages" on public.order_messages
    for select using (
        exists (
            select 1 from public.profiles p 
            where p.id = auth.uid() 
            and p.role in ('anchor', 'firstmate')
        )
    );

create policy "Fan can insert messages to own orders" on public.order_messages
    for insert with check (
        from_role = 'fan' 
        and exists (
            select 1 from public.orders o, public.profiles p
            where o.id = order_id 
            and o.user_id = auth.uid()
            and p.id = auth.uid()
            and p.role in ('fan', 'member')
        )
    );

create policy "Anchor can insert messages to any order" on public.order_messages
    for insert with check (
        from_role = 'anchor' 
        and exists (
            select 1 from public.profiles p 
            where p.id = auth.uid() 
            and p.role = 'anchor'
        )
    );

-- system_config 表 RLS
create policy "Everyone can read system config" on public.system_config
    for select using (true);

create policy "Only anchor can update system config" on public.system_config
    for update using (
        exists (
            select 1 from public.profiles p 
            where p.id = auth.uid() 
            and p.role = 'anchor'
        )
    );

-- ===================================================
-- 8. 触发器和函数
-- ===================================================

-- 更新 updated_at 字段的函数
create or replace function update_updated_at_column()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

-- 为相关表添加 updated_at 触发器
create trigger update_profiles_updated_at
    before update on public.profiles
    for each row execute function update_updated_at_column();

create trigger update_orders_updated_at
    before update on public.orders
    for each row execute function update_updated_at_column();

create trigger update_system_config_updated_at
    before update on public.system_config
    for each row execute function update_updated_at_column();

-- 用户注册后自动创建 profile 的函数
create or replace function public.handle_new_user()
returns trigger as $$
begin
    insert into public.profiles (id, email, nickname, role)
    values (
        new.id,
        new.email,
        coalesce(new.raw_user_meta_data->>'name', new.email),
        'fan'
    );
    return new;
end;
$$ language plpgsql security definer;

-- 用户注册触发器
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- 订单状态变更时更新时间戳的函数
create or replace function update_order_timestamps()
returns trigger as $$
begin
    if old.status != new.status then
        case new.status
            when 'queued' then
                new.queued_at = now();
            when 'completed' then
                new.completed_at = now();
            else
                -- 其他状态不特殊处理
        end case;
    end if;
    return new;
end;
$$ language plpgsql;

create trigger update_order_status_timestamps
    before update on public.orders
    for each row execute function update_order_timestamps();

-- ===================================================
-- 9. RPC 函数（供前端调用）
-- ===================================================

-- 获取排队列表（按优先级排序）
create or replace function get_queue_list()
returns table (
    order_id uuid,
    user_email text,
    user_nickname text,
    amount numeric,
    currency text,
    is_child_critical boolean,
    is_urgent boolean,
    created_at timestamptz,
    queued_at timestamptz,
    question_preview text
) as $$
begin
    return query
    select 
        o.id,
        p.email,
        p.nickname,
        o.amount,
        o.currency::text,
        o.is_child_critical,
        o.is_urgent,
        o.created_at,
        o.queued_at,
        left(o.question_content, 100) as question_preview
    from public.orders o
    join public.profiles p on o.user_id = p.id
    where o.status = 'queued'
    order by 
        o.amount desc,
        o.is_child_critical desc,
        o.is_urgent desc,
        o.created_at asc;
end;
$$ language plpgsql security definer;

-- 切换用户白名单状态
create or replace function toggle_user_whitelist(target_user_id uuid)
returns boolean as $$
declare
    current_role user_role;
    new_whitelist_status boolean;
begin
    -- 检查调用者权限
    select role into current_role
    from public.profiles 
    where id = auth.uid();
    
    if current_role != 'firstmate' then
        raise exception 'Unauthorized: Only firstmate can toggle whitelist';
    end if;
    
    -- 切换白名单状态和角色
    update public.profiles 
    set 
        is_whitelist = not is_whitelist,
        role = case 
            when is_whitelist then 'fan'::user_role
            else 'member'::user_role
        end
    where id = target_user_id
    returning is_whitelist into new_whitelist_status;
    
    return not new_whitelist_status; -- 返回新状态
end;
$$ language plpgsql security definer;

-- 获取订单统计数据
create or replace function get_order_statistics()
returns json as $$
declare
    result json;
begin
    select json_build_object(
        'total_orders', count(*),
        'draft_orders', count(*) filter (where status = 'draft'),
        'queued_orders', count(*) filter (where status = 'queued'),
        'completed_orders', count(*) filter (where status = 'completed'),
        'total_revenue', coalesce(sum(amount) filter (where status = 'completed'), 0),
        'avg_order_value', coalesce(avg(amount) filter (where status = 'completed'), 0)
    ) into result
    from public.orders;
    
    return result;
end;
$$ language plpgsql security definer;

-- ===================================================
-- 10. 初始数据
-- ===================================================

-- 可以在这里插入一些测试数据或默认管理员账户
-- 注意：实际部署时应该删除或修改这些测试数据

-- 创建示例系统管理员 (需要在实际使用时替换为真实的 UUID)
-- insert into public.profiles (id, email, nickname, role) values
--     ('00000000-0000-0000-0000-000000000001', 'admin@baidaohui.com', '系统管理员', 'anchor'),
--     ('00000000-0000-0000-0000-000000000002', 'firstmate@baidaohui.com', '助理', 'firstmate');

-- ===================================================
-- 完成初始化
-- ===================================================

-- 输出初始化完成信息
do $$
begin
    raise notice '百刀会数据库初始化完成！';
    raise notice '已创建表: profiles, orders, order_messages, system_config';
    raise notice '已配置 RLS 安全策略';
    raise notice '已创建必要的索引和触发器';
    raise notice '已创建 RPC 函数: get_queue_list, toggle_user_whitelist, get_order_statistics';
end $$;
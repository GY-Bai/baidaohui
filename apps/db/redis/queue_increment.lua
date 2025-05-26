-- 队列号自动增长脚本
-- 用于原子性地生成和管理算命申请的队列号
--
-- KEYS[1]: 队列计数器键 (fortune:queue:counter)
-- KEYS[2]: 队列排序键 (fortune:queue:sorted)
-- KEYS[3]: 订单详情键 (fortune:order:{order_id})
-- ARGV[1]: 订单ID
-- ARGV[2]: 用户ID
-- ARGV[3]: 金额（CAD）
-- ARGV[4]: 是否小孩危急 (1/0)
-- ARGV[5]: 提交时间戳
-- ARGV[6]: 货币类型

local counter_key = KEYS[1]
local sorted_key = KEYS[2]
local order_key = KEYS[3]
local order_id = ARGV[1]
local user_id = ARGV[2]
local amount_cad = tonumber(ARGV[3])
local is_child_urgent = tonumber(ARGV[4])
local timestamp = tonumber(ARGV[5])
local currency = ARGV[6]

-- 检查订单是否已存在
local existing_order = redis.call('HGET', order_key, 'queue_number')
if existing_order then
    return {err = "Order already has queue number", queue_number = existing_order}
end

-- 生成新的队列号
local queue_number = redis.call('INCR', counter_key)

-- 计算排序分数
-- 分数计算规则：
-- 1. 小孩危急：+1000000分
-- 2. 金额：每CAD 1元 = 100分
-- 3. 时间：越早提交分数越高（用负时间戳）
local score = 0

-- 小孩危急优先级
if is_child_urgent == 1 then
    score = score + 1000000
end

-- 金额优先级（每CAD 1元 = 100分）
score = score + (amount_cad * 100)

-- 时间优先级（越早提交分数越高）
-- 使用负时间戳，这样早提交的会有更高分数
score = score - timestamp

-- 将订单添加到有序集合
redis.call('ZADD', sorted_key, score, order_id)

-- 存储订单详情
redis.call('HMSET', order_key,
    'queue_number', queue_number,
    'user_id', user_id,
    'amount_cad', amount_cad,
    'is_child_urgent', is_child_urgent,
    'timestamp', timestamp,
    'currency', currency,
    'score', score,
    'status', 'queued'
)

-- 设置过期时间（30天）
redis.call('EXPIRE', order_key, 2592000)

-- 计算当前排队位置
local position = redis.call('ZREVRANK', sorted_key, order_id)
if position then
    position = position + 1  -- ZREVRANK返回0-based索引，转换为1-based
else
    position = 1
end

-- 获取总队列长度
local total_count = redis.call('ZCARD', sorted_key)

-- 计算排队百分比
local percentage = 0
if total_count > 0 then
    percentage = math.floor(((total_count - position) / total_count) * 100)
end

-- 更新位置信息
redis.call('HMSET', order_key,
    'queue_position', position,
    'queue_percentage', percentage,
    'total_in_queue', total_count
)

-- 发布队列更新事件
local event_data = cjson.encode({
    type = 'queue_update',
    order_id = order_id,
    queue_number = queue_number,
    position = position,
    percentage = percentage,
    total_count = total_count,
    is_child_urgent = is_child_urgent,
    amount_cad = amount_cad
})

redis.call('PUBLISH', 'fortune:queue:events', event_data)

-- 返回结果
return {
    ok = "Queue number assigned",
    queue_number = queue_number,
    position = position,
    percentage = percentage,
    total_count = total_count,
    score = score
} 
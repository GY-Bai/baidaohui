-- 聊天已读回执管理脚本
-- KEYS[1]: message_id
-- KEYS[2]: user_id
-- ARGV[1]: operation ('mark_read', 'get_readers', 'is_read')

local message_id = KEYS[1]
local user_id = KEYS[2]
local operation = ARGV[1]

local read_key = "message:read:" .. message_id

if operation == "mark_read" then
    -- 标记消息为已读
    local timestamp = redis.call('TIME')[1]
    redis.call('HSET', read_key, user_id, timestamp)
    redis.call('EXPIRE', read_key, 86400 * 7) -- 7天过期
    return 1
    
elseif operation == "get_readers" then
    -- 获取已读用户列表
    local readers = redis.call('HGETALL', read_key)
    return readers
    
elseif operation == "is_read" then
    -- 检查用户是否已读
    local read_time = redis.call('HGET', read_key, user_id)
    if read_time then
        return read_time
    else
        return nil
    end
    
elseif operation == "get_unread_count" then
    -- 获取用户未读消息数量
    -- ARGV[2]: room_id
    local room_id = ARGV[2]
    local room_messages_key = "room:messages:" .. room_id
    local user_last_read_key = "user:last_read:" .. user_id .. ":" .. room_id
    
    -- 获取用户最后读取时间
    local last_read_time = redis.call('GET', user_last_read_key)
    if not last_read_time then
        last_read_time = "0"
    end
    
    -- 计算未读消息数量
    local unread_count = redis.call('ZCOUNT', room_messages_key, "(" .. last_read_time, "+inf")
    return unread_count
    
elseif operation == "update_last_read" then
    -- 更新用户最后读取时间
    -- ARGV[2]: room_id
    -- ARGV[3]: timestamp
    local room_id = ARGV[2]
    local timestamp = ARGV[3]
    local user_last_read_key = "user:last_read:" .. user_id .. ":" .. room_id
    
    redis.call('SET', user_last_read_key, timestamp)
    redis.call('EXPIRE', user_last_read_key, 86400 * 30) -- 30天过期
    return 1
    
else
    return redis.error_reply("Invalid operation")
end 
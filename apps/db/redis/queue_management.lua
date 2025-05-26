-- 队列管理脚本
-- KEYS[1]: queue_key (例如: "fortune:queue")
-- ARGV[1]: operation ('add', 'remove', 'get_position', 'update_positions', 'get_next')
-- ARGV[2]: order_id (当operation为add/remove/get_position时)
-- ARGV[3]: priority_score (当operation为add时)

local queue_key = KEYS[1]
local operation = ARGV[1]

if operation == "add" then
    -- 添加订单到队列
    local order_id = ARGV[2]
    local priority_score = tonumber(ARGV[3])
    
    -- 使用负分数，这样分数越高的排在前面
    redis.call('ZADD', queue_key, -priority_score, order_id)
    
    -- 获取当前位置
    local position = redis.call('ZRANK', queue_key, order_id)
    return position + 1 -- 返回1基础的位置
    
elseif operation == "remove" then
    -- 从队列中移除订单
    local order_id = ARGV[2]
    local removed = redis.call('ZREM', queue_key, order_id)
    
    -- 重新计算所有位置
    if removed > 0 then
        redis.call('EVAL', [[
            local queue_key = KEYS[1]
            local members = redis.call('ZRANGE', queue_key, 0, -1)
            for i, member in ipairs(members) do
                -- 这里可以触发位置更新的通知
            end
        ]], 1, queue_key)
    end
    
    return removed
    
elseif operation == "get_position" then
    -- 获取订单在队列中的位置
    local order_id = ARGV[2]
    local position = redis.call('ZRANK', queue_key, order_id)
    
    if position then
        return position + 1 -- 返回1基础的位置
    else
        return nil
    end
    
elseif operation == "update_positions" then
    -- 更新所有订单的位置信息
    local members = redis.call('ZRANGE', queue_key, 0, -1, 'WITHSCORES')
    local total_count = redis.call('ZCARD', queue_key)
    local results = {}
    
    for i = 1, #members, 2 do
        local order_id = members[i]
        local position = (i + 1) / 2 -- 因为WITHSCORES返回的是交替的member和score
        local percentage = (position / total_count) * 100
        
        table.insert(results, order_id)
        table.insert(results, position)
        table.insert(results, percentage)
    end
    
    return results
    
elseif operation == "get_next" then
    -- 获取队列中的下一个订单
    local next_orders = redis.call('ZRANGE', queue_key, 0, 0)
    if #next_orders > 0 then
        return next_orders[1]
    else
        return nil
    end
    
elseif operation == "get_queue_info" then
    -- 获取队列信息
    local total_count = redis.call('ZCARD', queue_key)
    local all_members = redis.call('ZRANGE', queue_key, 0, -1, 'WITHSCORES')
    
    local queue_info = {
        total_count = total_count,
        members = {}
    }
    
    for i = 1, #all_members, 2 do
        local order_id = all_members[i]
        local score = all_members[i + 1]
        local position = (i + 1) / 2
        
        table.insert(queue_info.members, {
            order_id = order_id,
            position = position,
            score = score,
            percentage = (position / total_count) * 100
        })
    end
    
    return cjson.encode(queue_info)
    
elseif operation == "reorder" then
    -- 重新排序队列（当优先级规则改变时）
    -- ARGV[2]: 新的排序规则JSON
    local new_scores = cjson.decode(ARGV[2])
    
    for order_id, new_score in pairs(new_scores) do
        redis.call('ZADD', queue_key, -new_score, order_id)
    end
    
    return redis.call('ZCARD', queue_key)
    
else
    return redis.error_reply("Invalid operation")
end 
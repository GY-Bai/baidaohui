-- mod_xmpp_bridge.lua
-- XMPP桥接模块，实现与Flask API的集成
-- 处理HTTP请求和XMPP消息的双向转换

local st = require "util.stanza";
local jid_bare = require "util.jid".bare;
local jid_split = require "util.jid".split;
local datetime = require "util.datetime";
local uuid_generate = require "util.uuid".generate;
local json = require "util.json";
local http = require "net.http";

-- Redis连接配置
local redis = require "redis";
local redis_client = redis.connect("127.0.0.1", 6379);

-- 模块配置
local api_base_url = module:get_option_string("api_base_url", "http://localhost:5001");
local api_secret = module:get_option_string("api_secret", "your_api_secret_key");

module:depends("http");

-- HTTP API端点处理
local function handle_send_message(event)
    local request = event.request;
    local response = event.response;
    
    -- 验证API密钥
    local auth_header = request.headers.authorization;
    if not auth_header or auth_header ~= "Bearer " .. api_secret then
        response.status_code = 401;
        response:send(json.encode({error = "Unauthorized"}));
        return true;
    end
    
    -- 解析请求体
    local body_data = json.decode(request.body or "{}");
    if not body_data then
        response.status_code = 400;
        response:send(json.encode({error = "Invalid JSON"}));
        return true;
    end
    
    local from = body_data.from;
    local to = body_data.to;
    local message_body = body_data.body;
    local message_type = body_data.type or "chat";
    
    if not from or not to or not message_body then
        response.status_code = 400;
        response:send(json.encode({error = "Missing required fields: from, to, body"}));
        return true;
    end
    
    -- 创建XMPP消息
    local message_id = uuid_generate();
    local stanza = st.message({
        from = from,
        to = to,
        type = message_type,
        id = message_id
    }):tag("body"):text(message_body):up();
    
    -- 添加时间戳
    stanza:tag("delay", {
        xmlns = "urn:xmpp:delay",
        stamp = datetime.datetime()
    }):up();
    
    -- 发送消息
    module:send(stanza);
    
    -- 存储到Redis
    local message_key = string.format("chat:api_message:%s", message_id);
    redis_client:hset(message_key, {
        id = message_id,
        from = from,
        to = to,
        type = message_type,
        body = message_body,
        timestamp = datetime.datetime(),
        source = "api"
    });
    redis_client:expire(message_key, 86400 * 7); -- 7天过期
    
    -- 返回成功响应
    response.status_code = 200;
    response:send(json.encode({
        success = true,
        message_id = message_id,
        timestamp = datetime.datetime()
    }));
    
    module:log("info", "API message sent: %s -> %s", from, to);
    return true;
end

-- 获取消息历史
local function handle_get_messages(event)
    local request = event.request;
    local response = event.response;
    
    -- 验证API密钥
    local auth_header = request.headers.authorization;
    if not auth_header or auth_header ~= "Bearer " .. api_secret then
        response.status_code = 401;
        response:send(json.encode({error = "Unauthorized"}));
        return true;
    end
    
    -- 解析查询参数
    local query = request.url.query or {};
    local user_jid = query.user;
    local contact_jid = query.contact;
    local limit = tonumber(query.limit) or 50;
    local offset = tonumber(query.offset) or 0;
    
    if not user_jid then
        response.status_code = 400;
        response:send(json.encode({error = "Missing user parameter"}));
        return true;
    end
    
    -- 构建查询键
    local messages = {};
    local search_pattern;
    
    if contact_jid then
        -- 获取两个用户之间的对话
        search_pattern = string.format("chat:message:*");
    else
        -- 获取用户的所有消息
        search_pattern = string.format("chat:message:*");
    end
    
    -- 从Redis获取消息
    local message_keys = redis_client:keys(search_pattern);
    
    for _, key in ipairs(message_keys) do
        local message_data = redis_client:hgetall(key);
        
        -- 过滤消息
        local include_message = false;
        if contact_jid then
            include_message = (message_data.from == user_jid and message_data.to == contact_jid) or
                            (message_data.from == contact_jid and message_data.to == user_jid);
        else
            include_message = message_data.from == user_jid or message_data.to == user_jid;
        end
        
        if include_message then
            table.insert(messages, message_data);
        end
    end
    
    -- 按时间戳排序
    table.sort(messages, function(a, b)
        return a.timestamp > b.timestamp;
    end);
    
    -- 应用分页
    local total_count = #messages;
    local start_index = offset + 1;
    local end_index = math.min(offset + limit, total_count);
    local paginated_messages = {};
    
    for i = start_index, end_index do
        table.insert(paginated_messages, messages[i]);
    end
    
    -- 返回响应
    response.status_code = 200;
    response:send(json.encode({
        messages = paginated_messages,
        total_count = total_count,
        offset = offset,
        limit = limit,
        has_more = end_index < total_count
    }));
    
    return true;
end

-- 获取在线用户列表
local function handle_get_online_users(event)
    local request = event.request;
    local response = event.response;
    
    -- 验证API密钥
    local auth_header = request.headers.authorization;
    if not auth_header or auth_header ~= "Bearer " .. api_secret then
        response.status_code = 401;
        response:send(json.encode({error = "Unauthorized"}));
        return true;
    end
    
    -- 获取在线用户
    local online_users = {};
    local sessions = prosody.full_sessions;
    
    for full_jid, session in pairs(sessions) do
        local bare_jid = jid_bare(full_jid);
        if not online_users[bare_jid] then
            online_users[bare_jid] = {
                jid = bare_jid,
                resources = {},
                last_activity = session.last_activity or os.time()
            };
        end
        
        local node, host, resource = jid_split(full_jid);
        table.insert(online_users[bare_jid].resources, {
            resource = resource,
            priority = session.priority or 0,
            status = session.status or "available"
        });
    end
    
    -- 转换为数组
    local users_array = {};
    for _, user_data in pairs(online_users) do
        table.insert(users_array, user_data);
    end
    
    response.status_code = 200;
    response:send(json.encode({
        online_users = users_array,
        count = #users_array,
        timestamp = datetime.datetime()
    }));
    
    return true;
end

-- 处理房间管理
local function handle_room_management(event)
    local request = event.request;
    local response = event.response;
    
    -- 验证API密钥
    local auth_header = request.headers.authorization;
    if not auth_header or auth_header ~= "Bearer " .. api_secret then
        response.status_code = 401;
        response:send(json.encode({error = "Unauthorized"}));
        return true;
    end
    
    local method = request.method;
    local body_data = json.decode(request.body or "{}");
    
    if method == "POST" then
        -- 创建房间
        local room_jid = body_data.room_jid;
        local room_name = body_data.name;
        local room_description = body_data.description;
        local owner_jid = body_data.owner;
        
        if not room_jid or not owner_jid then
            response.status_code = 400;
            response:send(json.encode({error = "Missing room_jid or owner"}));
            return true;
        end
        
        -- 存储房间信息到Redis
        local room_key = string.format("chat:room:%s", room_jid);
        redis_client:hset(room_key, {
            jid = room_jid,
            name = room_name or "",
            description = room_description or "",
            owner = owner_jid,
            created_at = datetime.datetime()
        });
        
        -- 添加房间成员
        local members_key = string.format("chat:room_members:%s", room_jid);
        redis_client:sadd(members_key, owner_jid);
        
        response.status_code = 201;
        response:send(json.encode({
            success = true,
            room_jid = room_jid,
            message = "Room created successfully"
        }));
        
    elseif method == "PUT" then
        -- 添加/移除房间成员
        local room_jid = body_data.room_jid;
        local user_jid = body_data.user_jid;
        local action = body_data.action; -- "add" or "remove"
        
        if not room_jid or not user_jid or not action then
            response.status_code = 400;
            response:send(json.encode({error = "Missing required fields"}));
            return true;
        end
        
        local members_key = string.format("chat:room_members:%s", room_jid);
        
        if action == "add" then
            redis_client:sadd(members_key, user_jid);
        elseif action == "remove" then
            redis_client:srem(members_key, user_jid);
        else
            response.status_code = 400;
            response:send(json.encode({error = "Invalid action"}));
            return true;
        end
        
        response.status_code = 200;
        response:send(json.encode({
            success = true,
            message = string.format("User %s %s room %s", 
                                   action == "add" and "added to" or "removed from", 
                                   user_jid, room_jid)
        }));
        
    else
        response.status_code = 405;
        response:send(json.encode({error = "Method not allowed"}));
    end
    
    return true;
end

-- 消息转发到API
local function forward_message_to_api(stanza)
    local message_data = {
        id = stanza.attr.id,
        from = stanza.attr.from,
        to = stanza.attr.to,
        type = stanza.attr.type or "chat",
        body = stanza:get_child_text("body") or "",
        timestamp = datetime.datetime()
    };
    
    -- 异步发送到API
    http.request(api_base_url .. "/webhook/message", {
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. api_secret
        },
        body = json.encode(message_data)
    }, function(response_body, code, response)
        if code == 200 then
            module:log("debug", "Message forwarded to API successfully");
        else
            module:log("warn", "Failed to forward message to API: %d", code);
        end
    end);
end

-- 处理用户状态变化
local function handle_presence_change(event)
    local stanza = event.stanza;
    local from = stanza.attr.from;
    local to = stanza.attr.to;
    local presence_type = stanza.attr.type;
    
    local presence_data = {
        from = from,
        to = to,
        type = presence_type or "available",
        show = stanza:get_child_text("show") or "online",
        status = stanza:get_child_text("status") or "",
        timestamp = datetime.datetime()
    };
    
    -- 存储到Redis
    local presence_key = string.format("chat:presence:%s", jid_bare(from));
    redis_client:hset(presence_key, presence_data);
    redis_client:expire(presence_key, 3600); -- 1小时过期
    
    -- 转发到API
    http.request(api_base_url .. "/webhook/presence", {
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. api_secret
        },
        body = json.encode(presence_data)
    }, function(response_body, code, response)
        if code ~= 200 then
            module:log("warn", "Failed to forward presence to API: %d", code);
        end
    end);
end

-- 注册HTTP端点
module:provides("http", {
    route = {
        ["POST /send_message"] = handle_send_message;
        ["GET /messages"] = handle_get_messages;
        ["GET /online_users"] = handle_get_online_users;
        ["POST /rooms"] = handle_room_management;
        ["PUT /rooms"] = handle_room_management;
    };
});

-- 注册事件处理器
module:hook("message/full", function(event)
    forward_message_to_api(event.stanza);
end, 10);

module:hook("message/bare", function(event)
    forward_message_to_api(event.stanza);
end, 10);

module:hook("presence/full", handle_presence_change, 10);
module:hook("presence/bare", handle_presence_change, 10);

-- 模块卸载清理
module:hook_global("server-stopping", function()
    if redis_client then
        redis_client:quit();
    end
end);

module:log("info", "XMPP bridge module loaded successfully"); 
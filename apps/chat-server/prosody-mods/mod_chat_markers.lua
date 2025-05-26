-- mod_chat_markers.lua
-- 聊天标记模块，实现已读回执和消息状态管理
-- 支持Member私信转发到群聊，以及消息撤回功能

local st = require "util.stanza";
local jid_bare = require "util.jid".bare;
local jid_split = require "util.jid".split;
local datetime = require "util.datetime";
local uuid_generate = require "util.uuid".generate;

-- Redis连接配置
local redis = require "redis";
local redis_client = redis.connect("127.0.0.1", 6379);

-- 模块配置
local chat_markers_xmlns = "urn:xmpp:chat-markers:0";
local message_archive_xmlns = "urn:xmpp:mam:2";

-- 支持的标记类型
local marker_types = {
    received = true,
    displayed = true,
    acknowledged = true
};

-- 消息存储
local message_store = {};

module:depends("disco");

-- 添加功能声明
module:add_feature(chat_markers_xmlns);

-- 处理聊天标记
local function handle_chat_marker(event)
    local stanza = event.stanza;
    local from = stanza.attr.from;
    local to = stanza.attr.to;
    local marker = stanza:get_child(nil, chat_markers_xmlns);
    
    if not marker then
        return;
    end
    
    local marker_type = marker.name;
    local message_id = marker.attr.id;
    
    if not marker_types[marker_type] or not message_id then
        return;
    end
    
    module:log("debug", "Processing %s marker for message %s from %s to %s", 
               marker_type, message_id, from, to);
    
    -- 存储标记到Redis
    local marker_key = string.format("chat:marker:%s:%s:%s", 
                                    jid_bare(to), message_id, jid_bare(from));
    local marker_data = {
        type = marker_type,
        from = from,
        to = to,
        message_id = message_id,
        timestamp = datetime.datetime()
    };
    
    redis_client:hset(marker_key, marker_data);
    redis_client:expire(marker_key, 86400 * 7); -- 7天过期
    
    -- 如果是群聊消息的已读标记，需要特殊处理
    if marker_type == "displayed" and to:find("@conference.") then
        handle_group_chat_marker(from, to, message_id);
    end
    
    -- 转发标记给发送者
    local reply = st.message({
        from = to,
        to = from,
        type = stanza.attr.type or "chat"
    }):tag(marker_type, {
        xmlns = chat_markers_xmlns,
        id = message_id
    });
    
    module:send(reply);
    
    return true;
end

-- 处理群聊已读标记
local function handle_group_chat_marker(from, room_jid, message_id)
    local room_bare = jid_bare(room_jid);
    local user_bare = jid_bare(from);
    
    -- 记录用户已读状态
    local read_key = string.format("chat:room_read:%s:%s", room_bare, message_id);
    redis_client:sadd(read_key, user_bare);
    redis_client:expire(read_key, 86400 * 7); -- 7天过期
    
    -- 获取房间成员列表
    local members_key = string.format("chat:room_members:%s", room_bare);
    local members = redis_client:smembers(members_key);
    local read_members = redis_client:smembers(read_key);
    
    -- 计算已读百分比
    local total_members = #members;
    local read_count = #read_members;
    local read_percentage = total_members > 0 and (read_count / total_members * 100) or 0;
    
    -- 更新消息已读统计
    local stats_key = string.format("chat:message_stats:%s", message_id);
    redis_client:hset(stats_key, {
        total_members = total_members,
        read_count = read_count,
        read_percentage = read_percentage,
        last_updated = datetime.datetime()
    });
    redis_client:expire(stats_key, 86400 * 7);
    
    module:log("debug", "Group chat marker: %d/%d members read message %s (%.1f%%)", 
               read_count, total_members, message_id, read_percentage);
end

-- 处理消息撤回
local function handle_message_retract(event)
    local stanza = event.stanza;
    local from = stanza.attr.from;
    local to = stanza.attr.to;
    
    local retract = stanza:get_child("retract", "urn:xmpp:message-retract:0");
    if not retract then
        return;
    end
    
    local message_id = retract.attr.id;
    if not message_id then
        return;
    end
    
    module:log("debug", "Processing message retract for %s from %s", message_id, from);
    
    -- 检查权限：只有消息发送者或管理员可以撤回
    local original_message = get_message_from_store(message_id);
    if not original_message or 
       (jid_bare(original_message.from) ~= jid_bare(from) and not is_admin(from)) then
        -- 发送错误响应
        local error_reply = st.error_reply(stanza, "auth", "forbidden", 
                                         "You don't have permission to retract this message");
        module:send(error_reply);
        return true;
    end
    
    -- 标记消息为已撤回
    local retract_key = string.format("chat:retracted:%s", message_id);
    redis_client:set(retract_key, datetime.datetime());
    redis_client:expire(retract_key, 86400 * 30); -- 30天过期
    
    -- 发送撤回通知给所有相关用户
    local retract_notification = st.message({
        from = from,
        to = to,
        type = stanza.attr.type or "chat"
    }):tag("retracted", {
        xmlns = "urn:xmpp:message-retract:0",
        id = message_id,
        timestamp = datetime.datetime()
    });
    
    -- 如果是群聊，广播给所有成员
    if to:find("@conference.") then
        broadcast_to_room(to, retract_notification);
    else
        module:send(retract_notification);
    end
    
    return true;
end

-- 处理Member私信转发到群聊
local function handle_member_to_master_message(event)
    local stanza = event.stanza;
    local from = stanza.attr.from;
    local to = stanza.attr.to;
    local body = stanza:get_child_text("body");
    
    if not body then
        return;
    end
    
    local from_node, from_host = jid_split(from);
    local to_node, to_host = jid_split(to);
    
    -- 检查是否是Member发给Master的私信
    if to_node == "anchor" and to_host == "localhost" then
        local user_role = get_user_role(jid_bare(from));
        
        if user_role == "member" then
            -- 转发到群聊
            local group_jid = "#general@conference.localhost";
            local forwarded_message = st.message({
                from = from,
                to = group_jid,
                type = "groupchat",
                id = uuid_generate()
            }):tag("body"):text(string.format("[私信转发] %s: %s", 
                                             get_user_nickname(jid_bare(from)), body)):up()
              :tag("forwarded", { xmlns = "urn:xmpp:forward:0" })
              :tag("original_from"):text(from):up()
              :tag("original_to"):text(to):up();
            
            module:send(forwarded_message);
            
            -- 记录转发日志
            module:log("info", "Forwarded private message from %s to group chat", from);
            
            -- 存储转发记录
            local forward_key = string.format("chat:forwarded:%s", stanza.attr.id or uuid_generate());
            redis_client:hset(forward_key, {
                original_from = from,
                original_to = to,
                forwarded_to = group_jid,
                timestamp = datetime.datetime(),
                body = body
            });
            redis_client:expire(forward_key, 86400 * 30); -- 30天过期
        end
    end
end

-- 获取用户角色
function get_user_role(user_jid)
    local role_key = string.format("user:role:%s", user_jid);
    return redis_client:get(role_key) or "fan";
end

-- 获取用户昵称
function get_user_nickname(user_jid)
    local nickname_key = string.format("user:nickname:%s", user_jid);
    return redis_client:get(nickname_key) or user_jid;
end

-- 检查是否是管理员
function is_admin(user_jid)
    local role = get_user_role(user_jid);
    return role == "master" or role == "firstmate";
end

-- 从存储中获取消息
function get_message_from_store(message_id)
    local message_key = string.format("chat:message:%s", message_id);
    return redis_client:hgetall(message_key);
end

-- 广播消息到房间
function broadcast_to_room(room_jid, stanza)
    local room_bare = jid_bare(room_jid);
    local members_key = string.format("chat:room_members:%s", room_bare);
    local members = redis_client:smembers(members_key);
    
    for _, member in ipairs(members) do
        local member_stanza = st.clone(stanza);
        member_stanza.attr.to = member;
        module:send(member_stanza);
    end
end

-- 存储消息到Redis
local function store_message(stanza)
    local message_id = stanza.attr.id;
    if not message_id then
        message_id = uuid_generate();
        stanza.attr.id = message_id;
    end
    
    local message_key = string.format("chat:message:%s", message_id);
    local message_data = {
        id = message_id,
        from = stanza.attr.from,
        to = stanza.attr.to,
        type = stanza.attr.type or "chat",
        body = stanza:get_child_text("body") or "",
        timestamp = datetime.datetime(),
        thread = stanza:get_child_text("thread") or ""
    };
    
    redis_client:hset(message_key, message_data);
    redis_client:expire(message_key, 86400 * 30); -- 30天过期
    
    return message_id;
end

-- 注册事件处理器
module:hook("pre-message/full", handle_member_to_master_message, 100);
module:hook("pre-message/bare", handle_member_to_master_message, 100);
module:hook("message/full", handle_chat_marker, 50);
module:hook("message/bare", handle_chat_marker, 50);
module:hook("message/full", handle_message_retract, 60);
module:hook("message/bare", handle_message_retract, 60);

-- 存储所有消息
module:hook("pre-message/full", store_message, 10);
module:hook("pre-message/bare", store_message, 10);

-- 模块卸载清理
module:hook_global("server-stopping", function()
    if redis_client then
        redis_client:quit();
    end
end);

module:log("info", "Chat markers module loaded successfully"); 
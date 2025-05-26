-- Prosody XMPP服务器配置

-- 管理员账户
admins = { "admin@chat.baidaohui.com" }

-- 启用的模块
modules_enabled = {
    -- 通用模块
    "roster"; -- 联系人列表
    "saslauth"; -- SASL认证
    "tls"; -- TLS加密
    "dialback"; -- 服务器间验证
    "disco"; -- 服务发现
    "carbons"; -- 消息副本
    "pep"; -- 个人事件协议
    "private"; -- 私有存储
    "blocklist"; -- 黑名单
    "vcard4"; -- vCard支持
    "vcard_legacy"; -- 旧版vCard支持
    "limits"; -- 连接限制
    "version"; -- 版本查询
    "uptime"; -- 运行时间
    "time"; -- 时间查询
    "ping"; -- Ping支持
    "register"; -- 用户注册
    "admin_adhoc"; -- 管理命令

    -- HTTP模块
    "http"; -- HTTP服务器
    "http_files"; -- 静态文件服务
    "bosh"; -- BOSH (HTTP绑定)
    "websocket"; -- WebSocket支持

    -- 多用户聊天
    "muc"; -- 多用户聊天
    "muc_mam"; -- MUC消息存档

    -- 消息存档
    "mam"; -- 消息存档管理

    -- 推送通知
    "cloud_notify"; -- 推送通知支持
}

-- 禁用的模块
modules_disabled = {
    "s2s"; -- 暂时禁用服务器间通信
}

-- 允许注册
allow_registration = true

-- 数据存储
storage = "internal"

-- 日志配置
log = {
    info = "/var/log/prosody/prosody.log";
    error = "/var/log/prosody/prosody.err";
    "*syslog";
}

-- 虚拟主机配置
VirtualHost "chat.baidaohui.com"
    enabled = true
    
    -- SSL证书
    ssl = {
        key = "/etc/prosody/certs/key.pem";
        certificate = "/etc/prosody/certs/cert.pem";
    }

-- 多用户聊天组件
Component "conference.chat.baidaohui.com" "muc"
    name = "百道会聊天室"
    modules_enabled = {
        "muc_mam";
        "vcard_muc";
    }

-- HTTP配置
http_ports = { 5280 }
http_interfaces = { "*" }

-- BOSH配置
consider_bosh_secure = true
cross_domain_bosh = true

-- WebSocket配置
consider_websocket_secure = true
cross_domain_websocket = true

-- 安全设置
c2s_require_encryption = false
s2s_require_encryption = false
s2s_secure_auth = false

-- 认证配置
authentication = "internal_hashed"

-- 网络设置
interfaces = { "*" }
c2s_ports = { 5222 }
s2s_ports = { 5269 }

-- 插件路径
plugin_paths = { "/usr/lib/prosody/modules-enabled" } 
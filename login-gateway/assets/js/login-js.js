// 环境配置
const SUPABASE_URL = window?.ENV?.SUPABASE_URL;
const SUPABASE_ANON_KEY = window?.ENV?.SUPABASE_ANON_KEY;

// 验证环境变量
if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    console.error('环境变量未正确加载:', { SUPABASE_URL, SUPABASE_ANON_KEY });
    throw new Error('环境变量未正确加载');
}

// 验证 URL 格式
try {
    new URL(SUPABASE_URL);
} catch (error) {
    console.error('无效的 SUPABASE_URL:', SUPABASE_URL);
    throw new Error('无效的 SUPABASE_URL');
}

// 角色对应的重定向URL
const ROLE_REDIRECTS = {
    fan: 'https://fans.baidaohui.com',
    member: 'https://fans.baidaohui.com',
    anchor: 'https://master.baidaohui.com',
    firstmate: 'https://firstmate.baidaohui.com'
};

// 初始化 Supabase 客户端
const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// DOM 元素
const googleLoginBtn = document.getElementById('googleLoginBtn');
const loadingDiv = document.getElementById('loading');
const errorDiv = document.getElementById('error');

// 工具函数
function showLoading(show = true) {
    loadingDiv.style.display = show ? 'block' : 'none';
    googleLoginBtn.disabled = show;
}

function showError(message) {
    errorDiv.textContent = message;
    errorDiv.style.display = 'block';
    setTimeout(() => {
        errorDiv.style.display = 'none';
    }, 5000);
}

function hideError() {
    errorDiv.style.display = 'none';
}

// 获取用户角色
async function getUserRole(userId) {
    try {
        // 首先尝试从 user_metadata 获取角色
        const { data: { user } } = await supabaseClient.auth.getUser();
        if (user?.user_metadata?.role) {
            return user.user_metadata.role;
        }

        // 如果 metadata 中没有角色，调用 RPC 函数
        const { data, error } = await supabaseClient.rpc('get_role', { uid: userId });
        
        if (error) {
            console.error('获取角色失败:', error);
            return null;
        }
        
        return data || null;
    } catch (error) {
        console.error('获取角色时发生错误:', error);
        return null;
    }
}

// 检查用户昵称
function hasNickname(user) {
    return user?.user_metadata?.nickname || 
           user?.user_metadata?.display_name || 
           user?.user_metadata?.full_name ||
           user?.user_metadata?.name;
}

// 处理登录成功后的重定向
async function handleLoginSuccess(session) {
    try {
        const user = session.user;
        
        // 检查是否有昵称，如果没有则跳转到设置页面
        if (!hasNickname(user)) {
            console.log('用户未设置昵称，跳转到设置页面');
            window.location.href = 'set-profile.html';
            return;
        }

        // 获取用户角色
        const role = await getUserRole(user.id);
        console.log('用户角色:', role);

        // 根据角色决定重定向URL
        let redirectUrl;
        if (role && ROLE_REDIRECTS[role]) {
            redirectUrl = ROLE_REDIRECTS[role];
        } else {
            // 默认重定向到 fans 页面
            redirectUrl = ROLE_REDIRECTS.fan;
        }

        console.log('重定向到:', redirectUrl);
        
        // 添加一个短暂的延迟让用户看到成功状态
        setTimeout(() => {
            window.location.href = redirectUrl;
        }, 1000);

    } catch (error) {
        console.error('处理登录成功时发生错误:', error);
        showError('登录处理失败，请稍后重试');
        showLoading(false);
    }
}

// Google OAuth 登录
async function signInWithGoogle() {
    try {
        hideError();
        showLoading(true);

        console.log('开始 Google 登录...');
        
        const { data, error } = await supabaseClient.auth.signInWithOAuth({
            provider: 'google',
            options: {
                redirectTo: window.location.origin + window.location.pathname,
                queryParams: {
                    access_type: 'offline',
                    prompt: 'consent',
                }
            }
        });

        if (error) {
            throw error;
        }

        // OAuth 登录会触发页面重定向，这里不需要额外处理
        console.log('Google 登录请求已发送');

    } catch (error) {
        console.error('Google 登录失败:', error);
        showError('登录失败: ' + (error.message || '未知错误'));
        showLoading(false);
    }
}

// 检查当前会话状态
async function checkSession() {
    try {
        const { data: { session }, error } = await supabaseClient.auth.getSession();
        
        if (error) {
            console.error('检查会话失败:', error);
            return;
        }

        if (session) {
            console.log('发现现有会话，处理登录');
            showLoading(true);
            await handleLoginSuccess(session);
        }
    } catch (error) {
        console.error('检查会话时发生错误:', error);
    }
}

// 监听认证状态变化
supabaseClient.auth.onAuthStateChange(async (event, session) => {
    console.log('认证状态变化:', event, session?.user?.email);
    
    if (event === 'SIGNED_IN' && session) {
        await handleLoginSuccess(session);
    } else if (event === 'SIGNED_OUT') {
        showLoading(false);
        console.log('用户已登出');
    } else if (event === 'TOKEN_REFRESHED') {
        console.log('令牌已刷新');
    }
});

// 事件监听器
googleLoginBtn.addEventListener('click', signInWithGoogle);

// 页面加载时检查现有会话
document.addEventListener('DOMContentLoaded', () => {
    console.log('页面加载完成，检查会话状态');
    checkSession();
});

// 处理页面可见性变化（当用户从OAuth页面返回时）
document.addEventListener('visibilitychange', () => {
    if (!document.hidden) {
        console.log('页面变为可见，检查会话状态');
        setTimeout(checkSession, 500); // 给一些时间让认证状态更新
    }
});

// 错误处理
window.addEventListener('error', (event) => {
    console.error('全局错误:', event.error);
    showError('发生未预期的错误，请刷新页面重试');
    showLoading(false);
});

// 未处理的Promise拒绝
window.addEventListener('unhandledrejection', (event) => {
    console.error('未处理的Promise拒绝:', event.reason);
    showError('发生网络错误，请检查网络连接');
    showLoading(false);
});
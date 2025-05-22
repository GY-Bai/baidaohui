// 环境配置
function getMetaContent(name) {
    return document.querySelector(`meta[name="${name}"]`)?.content;
}

const SUPABASE_URL = getMetaContent("SUPABASE_URL");
const SUPABASE_ANON_KEY = getMetaContent("SUPABASE_ANON_KEY");

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
const profileForm = document.getElementById('profileForm');
const nicknameInput = document.getElementById('nickname');
const charCount = document.querySelector('.char-count');
const submitBtn = document.getElementById('submitBtn');
const skipBtn = document.getElementById('skipBtn');
const loadingDiv = document.getElementById('loading');
const errorDiv = document.getElementById('error');
const successDiv = document.getElementById('success');
const userAvatar = document.getElementById('userAvatar');

let currentUser = null;

// 工具函数
function showLoading(show = true) {
    loadingDiv.style.display = show ? 'block' : 'none';
    submitBtn.disabled = show;
    skipBtn.disabled = show;
}

function showError(message) {
    errorDiv.textContent = message;
    errorDiv.style.display = 'block';
    successDiv.style.display = 'none';
    setTimeout(() => {
        errorDiv.style.display = 'none';
    }, 5000);
}

function showSuccess(message) {
    successDiv.textContent = message;
    successDiv.style.display = 'block';
    errorDiv.style.display = 'none';
    setTimeout(() => {
        successDiv.style.display = 'none';
    }, 3000);
}

function hideMessages() {
    errorDiv.style.display = 'none';
    successDiv.style.display = 'none';
}

// 验证昵称
function validateNickname(nickname) {
    const trimmed = nickname.trim();
    
    if (!trimmed) {
        return { valid: false, message: '昵称不能为空' };
    }
    
    if (trimmed.length > 20) {
        return { valid: false, message: '昵称不能超过20个字符' };
    }
    
    // 检查是否包含特殊字符（允许中文、英文、数字、空格）
    const validPattern = /^[\u4e00-\u9fa5a-zA-Z0-9\s]+$/;
    if (!validPattern.test(trimmed)) {
        return { valid: false, message: '昵称只能包含中文、英文、数字和空格' };
    }
    
    return { valid: true, nickname: trimmed };
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

// 更新用户昵称
async function updateUserNickname(nickname) {
    try {
        const { data, error } = await supabaseClient.auth.updateUser({
            data: { 
                nickname: nickname,
                display_name: nickname 
            }
        });

        if (error) {
            throw error;
        }

        return data;
    } catch (error) {
        console.error('更新昵称失败:', error);
        throw error;
    }
}

// 处理重定向
async function handleRedirect() {
    try {
        if (!currentUser) {
            throw new Error('用户信息不存在');
        }

        // 获取用户角色
        const role = await getUserRole(currentUser.id);
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
        
        // 显示成功消息并重定向
        showSuccess('设置成功！正在跳转...');
        setTimeout(() => {
            window.location.href = redirectUrl;
        }, 1500);

    } catch (error) {
        console.error('处理重定向时发生错误:', error);
        showError('跳转失败，请稍后重试');
        showLoading(false);
    }
}

// 跳过昵称设置
async function skipNicknameSetting() {
    try {
        showLoading(true);
        await handleRedirect();
    } catch (error) {
        console.error('跳过设置时发生错误:', error);
        showError('操作失败，请稍后重试');
        showLoading(false);
    }
}

// 初始化用户信息
async function initializeUser() {
    try {
        const { data: { user }, error } = await supabaseClient.auth.getUser();
        
        if (error) {
            throw error;
        }

        if (!user) {
            console.log('用户未登录，重定向到登录页');
            window.location.href = 'index.html';
            return;
        }

        currentUser = user;
        
        // 设置用户头像
        if (user.user_metadata?.avatar_url || user.user_metadata?.picture) {
            const avatarUrl = user.user_metadata.avatar_url || user.user_metadata.picture;
            userAvatar.innerHTML = `<img src="${avatarUrl}" alt="用户头像">`;
        }

        // 如果用户已有昵称，预填充
        const existingNickname = user.user_metadata?.nickname || 
                                user.user_metadata?.display_name || 
                                user.user_metadata?.full_name ||
                                user.user_metadata?.name;
        
        if (existingNickname) {
            nicknameInput.value = existingNickname;
            updateCharCount();
        }

        console.log('用户信息已加载:', user.email);
        
    } catch (error) {
        console.error('初始化用户信息失败:', error);
        showError('加载用户信息失败，请刷新页面重试');
        
        // 如果是认证错误，重定向到登录页
        if (error.message.includes('Auth') || error.message.includes('JWT')) {
            setTimeout(() => {
                window.location.href = 'index.html';
            }, 2000);
        }
    }
}

// 更新字符计数
function updateCharCount() {
    const count = nicknameInput.value.length;
    charCount.textContent = `${count}/20`;
    
    if (count > 15) {
        charCount.style.color = '#e74c3c';
    } else if (count > 10) {
        charCount.style.color = '#f39c12';
    } else {
        charCount.style.color = '#999';
    }
}

// 处理表单提交
async function handleSubmit(event) {
    event.preventDefault();
    
    const nickname = nicknameInput.value;
    const validation = validateNickname(nickname);
    
    if (!validation.valid) {
        showError(validation.message);
        return;
    }

    try {
        hideMessages();
        showLoading(true);
        
        console.log('更新昵称:', validation.nickname);
        await updateUserNickname(validation.nickname);
        
        console.log('昵称更新成功');
        await handleRedirect();
        
    } catch (error) {
        console.error('保存昵称失败:', error);
        showError('保存失败: ' + (error.message || '未知错误'));
        showLoading(false);
    }
}

// 事件监听器
profileForm.addEventListener('submit', handleSubmit);
skipBtn.addEventListener('click', skipNicknameSetting);

// 昵称输入框事件
nicknameInput.addEventListener('input', updateCharCount);
nicknameInput.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') {
        event.preventDefault();
        handleSubmit(event);
    }
});

// 监听认证状态变化
supabaseClient.auth.onAuthStateChange((event, session) => {
    console.log('认证状态变化:', event);
    
    if (event === 'SIGNED_OUT' || !session) {
        console.log('用户已登出，重定向到登录页');
        window.location.href = 'index.html';
    }
});

// 页面加载时初始化
document.addEventListener('DOMContentLoaded', () => {
    console.log('昵称设置页面加载完成');
    initializeUser();
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
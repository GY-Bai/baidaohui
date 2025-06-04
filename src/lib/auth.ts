import { createClient } from '@supabase/supabase-js';
import { browser } from '$app/environment';
import { goto } from '$app/navigation';
import { redirect } from '@sveltejs/kit';

// 从环境变量获取Supabase配置
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'https://placeholder.supabase.co';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || 'placeholder_key';

// 只在运行时检查环境变量（不在构建时）
function checkEnvironmentVariables() {
  const hasUrl = import.meta.env.VITE_SUPABASE_URL && import.meta.env.VITE_SUPABASE_URL !== 'https://placeholder.supabase.co';
  const hasKey = import.meta.env.VITE_SUPABASE_ANON_KEY && import.meta.env.VITE_SUPABASE_ANON_KEY !== 'placeholder_key';
  
  if (browser && (!hasUrl || !hasKey)) {
    console.error('Missing Supabase environment variables. Please check VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY');
    return false;
  }
  return true;
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

export type UserRole = 'Fan' | 'Member' | 'Master' | 'Firstmate' | 'Seller';

export interface User {
  id: string;
  email: string;
  role: UserRole;
  nickname?: string;
}

export interface UserSession {
  user: User;
  access_token?: string;
}

// 角色对应的路径映射
export const rolePaths: Record<UserRole, string> = {
  Fan: '/fan',
  Member: '/member',
  Master: '/master',
  Firstmate: '/firstmate',
  Seller: '/seller'
};

// Google登录 - 纯Supabase实现
export async function signInWithGoogle() {
  if (!checkEnvironmentVariables()) {
    throw new Error('Supabase configuration is missing');
  }
  
  try {
    // 构建回调URL，确保与Supabase配置一致
    const baseUrl = import.meta.env.VITE_APP_URL || window.location.origin;
    const redirectUrl = `${baseUrl}/login/callback`;
    
    console.log('Google登录重定向URL:', redirectUrl);
    
    const { data, error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: redirectUrl
      }
    });
    
    if (error) throw error;
    return data;
  } catch (error) {
    console.error('登录失败:', error);
    throw error;
  }
}

// 获取当前会话 - 强制从数据库查询最新角色
export async function getSession(): Promise<User | null> {
  if (!checkEnvironmentVariables()) {
    console.error('Supabase configuration is missing');
    return null;
  }
  
  try {
    const { data: { session }, error } = await supabase.auth.getSession();
    
    if (error) throw error;
    if (!session) return null;

    console.log('🔍 获取到Supabase会话，用户ID:', session.user.id);

    // 🚀 关键修改：使用公共视图查询角色，避免RLS权限问题
    const { data: profile, error: profileError } = await supabase
      .from('profiles_public_roles')
      .select('role')
      .eq('id', session.user.id)
      .single();

    if (profileError) {
      console.error('❌ 查询用户角色失败:', profileError.message, profileError);
      // 如果查询失败，使用默认角色，但记录错误
      console.warn('⚠️ 使用默认角色 Fan，原因:', profileError.message);
    }

    const currentRole = profile?.role || 'Fan';
    const userMetadataRole = session.user.user_metadata?.role || 'Fan';
    
    // 🔍 调试日志：对比数据库角色和metadata角色
    if (currentRole !== userMetadataRole) {
      console.log(`🔄 角色不同步检测：`);
      console.log(`   数据库角色: ${currentRole}`);
      console.log(`   Metadata角色: ${userMetadataRole}`);
      console.log(`   ✅ 使用数据库角色: ${currentRole}`);
      
      // 🚀 自动尝试同步JWT metadata（异步执行，不阻塞当前流程）
      console.log('🔄 自动启动角色同步...');
      forceUpdateJWTMetadata(session.user.id, currentRole as UserRole, {
        auto_sync: true,
        detected_at: new Date().toISOString()
      }).then(result => {
        if (result.success) {
          console.log('✅ 自动角色同步成功');
        } else {
          console.warn('⚠️ 自动角色同步失败:', result.error);
        }
      }).catch(error => {
        console.warn('⚠️ 自动角色同步异常:', error);
      });
    } else {
      console.log(`✅ 角色同步正常: ${currentRole}`);
    }

    return {
      id: session.user.id,
      email: session.user.email || '',
      role: currentRole as UserRole, // 🎯 使用数据库中的最新角色
      nickname: session.user.user_metadata?.nickname || session.user.user_metadata?.full_name
    };
  } catch (error) {
    console.error('❌ 获取会话失败:', error);
    return null;
  }
}

// 处理URL片段中的会话（用于OAuth回调）
export async function handleAuthCallback(): Promise<User | null> {
  if (!browser || !checkEnvironmentVariables()) {
    return null;
  }

  try {
    // 检查URL是否包含认证片段
    const hashParams = new URLSearchParams(window.location.hash.substring(1));
    const accessToken = hashParams.get('access_token');
    
    if (accessToken) {
      console.log('🔍 检测到URL中的access_token，等待Supabase处理...');
      
      // 等待Supabase处理URL片段
      await new Promise(resolve => setTimeout(resolve, 100));
      
      // 清理URL（移除片段）
      const cleanUrl = window.location.pathname + window.location.search;
      window.history.replaceState({}, document.title, cleanUrl);
    }

    // 🚀 关键改进：获取处理后的会话（现在会查询最新角色）
    console.log('🔄 OAuth回调：开始获取最新用户角色...');
    const user = await getSession();
    
    if (user) {
      console.log(`✅ OAuth回调：成功获取用户会话`);
      console.log(`   用户ID: ${user.id}`);
      console.log(`   邮箱: ${user.email}`);
      console.log(`   角色: ${user.role}`);
      console.log(`   昵称: ${user.nickname || '未设置'}`);
    } else {
      console.log('⚠️ OAuth回调：未能获取用户会话');
    }

    return user;
  } catch (error) {
    console.error('❌ 处理认证回调失败:', error);
    return null;
  }
}

// 获取Supabase访问令牌
export async function getAccessToken(): Promise<string | null> {
  if (!checkEnvironmentVariables()) {
    console.error('Supabase configuration is missing');
    return null;
  }
  
  try {
    const { data: { session }, error } = await supabase.auth.getSession();
    if (error) throw error;
    return session?.access_token || null;
  } catch (error) {
    console.error('获取访问令牌失败:', error);
    return null;
  }
}

// 登出 - 纯Supabase实现
export async function signOut() {
  if (!checkEnvironmentVariables()) {
    console.error('Supabase configuration is missing');
    return;
  }
  
  try {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
    
    if (browser) {
      goto('/login');
    }
  } catch (error) {
    console.error('登出失败:', error);
    throw error;
  }
}

// 客户端路由守卫 - 增强角色验证
export async function clientSideRouteGuard(requiredRole?: UserRole): Promise<boolean> {
  if (!browser) {
    console.log('⚠️ 非浏览器环境，跳过客户端路由守卫');
    return false;
  }

  try {
    console.log(`🛡️ 客户端路由守卫：检查访问权限`);
    console.log(`   当前页面: ${window.location.pathname}`);
    console.log(`   要求角色: ${requiredRole || '任意'}`);
    
    // 🚀 获取最新的用户会话（现在会查询数据库中的最新角色）
    const user = await getSession();
    
    if (!user) {
      console.log('❌ 客户端路由守卫：用户未登录，重定向到登录页');
      goto('/login');
      return false;
    }

    console.log(`✅ 客户端路由守卫：用户已登录`);
    console.log(`   用户ID: ${user.id}`);
    console.log(`   邮箱: ${user.email}`);
    console.log(`   当前角色: ${user.role}`);

    // 🎯 如果指定了必需角色，进行角色验证
    if (requiredRole && user.role !== requiredRole) {
      console.log(`🚫 客户端路由守卫：角色不匹配`);
      console.log(`   当前角色: ${user.role}`);
      console.log(`   要求角色: ${requiredRole}`);
      console.log(`🔄 重定向到正确的角色页面...`);
      
      // 重定向到用户实际角色对应的页面
      redirectToRolePath(user.role);
      return false;
    }

    console.log(`✅ 客户端路由守卫：访问权限验证通过`);
    return true;
  } catch (error) {
    console.error('❌ 客户端路由守卫：验证过程出错:', error);
    goto('/login');
    return false;
  }
}

// 根据角色重定向到对应路径
export function redirectToRolePath(role: UserRole) {
  if (!browser) {
    console.log('⚠️ 非浏览器环境，跳过重定向');
    return;
  }
  
  const path = rolePaths[role];
  console.log(`🎯 重定向到角色页面:`);
  console.log(`   当前角色: ${role}`);
  console.log(`   目标路径: ${path}`);
  console.log(`   当前路径: ${window.location.pathname}`);
  
  if (path) {
    // 检查是否已经在正确的页面
    if (window.location.pathname === path) {
      console.log('✅ 已在正确页面，无需重定向');
      return;
    }
    
    console.log(`🚀 执行重定向: ${window.location.pathname} -> ${path}`);
    goto(path);
  } else {
    console.error(`❌ 未找到角色 ${role} 对应的路径，重定向到登录页`);
    goto('/login');
  }
}

// 检查当前路径是否匹配用户角色
export function isCorrectPath(role: UserRole): boolean {
  if (!browser) return true;
  
  const currentPath = window.location.pathname;
  const expectedPath = rolePaths[role];
  
  return currentPath.startsWith(expectedPath);
}

// 格式化时间
export function formatTime(timestamp: string | Date): string {
  return new Date(timestamp).toLocaleTimeString('zh-CN', {
    hour: '2-digit',
    minute: '2-digit'
  });
}

// 格式化日期
export function formatDate(timestamp: string | Date): string {
  return new Date(timestamp).toLocaleDateString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  });
}

// 格式化货币
export function formatCurrency(amount: number, currency: string = 'CAD'): string {
  return new Intl.NumberFormat('zh-CN', {
    style: 'currency',
    currency: currency
  }).format(amount);
}

// 客户端角色验证和重定向
export async function validateRoleAndRedirect(expectedRole: UserRole): Promise<boolean> {
  if (!browser) return true;
  
  try {
    const user = await getSession();
    
    if (!user) {
      // 未登录，重定向到登录页
      goto('/login');
      return false;
    }
    
    if (user.role !== expectedRole) {
      // 角色不匹配，重定向到对应角色页面
      redirectToRolePath(user.role);
      return false;
    }
    
    // 检查是否在正确的路径
    if (!isCorrectPath(expectedRole)) {
      redirectToRolePath(expectedRole);
      return false;
    }
    
    return true;
  } catch (error) {
    console.error('角色验证失败:', error);
    goto('/login');
    return false;
  }
}

// 简化的API调用函数，用于后端服务通信
export async function apiCall(endpoint: string, options: RequestInit = {}) {
  if (!browser) {
    throw new Error('API调用只能在浏览器环境中使用');
  }

  try {
    // 获取Supabase访问令牌
    const token = await getAccessToken();
    
    if (!token) {
      throw new Error('未找到访问令牌，请重新登录');
    }

    // 默认配置
    const defaultOptions: RequestInit = {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
        ...options.headers,
      },
      credentials: 'include',
      ...options,
    };

    // 构建完整URL (假设后端服务在特定端点)
    const baseUrl = import.meta.env.VITE_API_BASE_URL || 'https://api.baidaohui.com';
    const url = endpoint.startsWith('http') ? endpoint : `${baseUrl}${endpoint}`;

    const response = await fetch(url, defaultOptions);

    if (!response.ok) {
      if (response.status === 401) {
        // 认证失败，重定向到登录页
        goto('/login');
        throw new Error('认证失败，请重新登录');
      }
      throw new Error(`API调用失败: ${response.statusText}`);
    }

    // 如果响应是空的，返回null
    const text = await response.text();
    if (!text) {
      return null;
    }

    try {
      return JSON.parse(text);
    } catch {
      return text;
    }
  } catch (error) {
    console.error('API调用错误:', error);
    throw error;
  }
}

/**
 * 强制同步JWT中的用户metadata与数据库
 * 这个函数会更新Supabase Auth中的用户metadata，确保JWT包含最新的角色信息
 */
export async function forceUpdateJWTMetadata(
  userId: string,
  newRole: UserRole,
  additionalMetadata?: Record<string, any>
): Promise<{
  success: boolean;
  error?: string;
}> {
  if (!browser) {
    return {
      success: false,
      error: '此功能只能在浏览器环境中使用'
    };
  }

  if (!checkEnvironmentVariables()) {
    return {
      success: false,
      error: 'Supabase配置缺失'
    };
  }

  try {
    console.log(`🔄 强制更新JWT metadata: ${userId} -> ${newRole}`);
    
    // 获取当前用户信息
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    
    if (userError || !user) {
      return {
        success: false,
        error: '无法获取当前用户信息'
      };
    }

    // 只有当前用户才能更新自己的metadata
    if (user.id !== userId) {
      return {
        success: false,
        error: '只能更新自己的用户信息'
      };
    }

    // 准备新的metadata
    const newMetadata = {
      ...user.user_metadata,
      role: newRole,
      last_role_update: new Date().toISOString(),
      ...additionalMetadata
    };

    console.log('📝 更新用户metadata:', newMetadata);

    // 更新用户metadata
    const { data: updateData, error: updateError } = await supabase.auth.updateUser({
      data: newMetadata
    });

    if (updateError) {
      console.error('❌ 更新用户metadata失败:', updateError);
      return {
        success: false,
        error: `更新metadata失败: ${updateError.message}`
      };
    }

    console.log('✅ 用户metadata更新成功:', updateData);

    // 强制刷新session以获取最新的JWT
    const { data: sessionData, error: sessionError } = await supabase.auth.refreshSession();

    if (sessionError) {
      console.error('❌ 刷新session失败:', sessionError);
      return {
        success: false,
        error: `刷新session失败: ${sessionError.message}`
      };
    }

    console.log('✅ JWT metadata同步完成');
    return {
      success: true
    };

  } catch (error) {
    console.error('❌ 强制更新JWT metadata过程中发生错误:', error);
    return {
      success: false,
      error: `更新失败: ${error instanceof Error ? error.message : '未知错误'}`
    };
  }
}

/**
 * 更新用户角色并立即刷新JWT Session
 * 
 * 为什么要先更新数据库再刷新Session：
 * 1. 数据库是权威数据源，必须先确保数据库中的角色信息已正确更新
 * 2. 如果先刷新Session，JWT中的角色信息可能与数据库不一致
 * 3. 遵循"先写后读"的原则，确保数据一致性
 * 
 * refreshSession()的作用：
 * 1. 重新从Supabase Auth服务获取最新的JWT token
 * 2. 新的JWT会包含最新的用户metadata（包括角色信息）
 * 3. 确保前端的权限校验基于最新的角色信息
 * 4. 避免用户需要重新登录才能获得新权限
 */
export async function updateUserRoleAndRefreshSession(
  userId: string, 
  newRole: UserRole,
  additionalData?: Record<string, any>
): Promise<{
  success: boolean;
  user?: User;
  error?: string;
}> {
  if (!browser) {
    return {
      success: false,
      error: '此功能只能在浏览器环境中使用'
    };
  }

  if (!checkEnvironmentVariables()) {
    return {
      success: false,
      error: 'Supabase配置缺失'
    };
  }

  try {
    console.log(`🔄 开始更新用户角色: ${userId} -> ${newRole}`);
    
    // 第一步：更新数据库中的角色信息
    // 注意：这里直接更新profiles表，需要确保当前用户有相应权限（通常是管理员）
    const updateData = {
      role: newRole,
      updated_at: new Date().toISOString(),
      ...additionalData
    };

    console.log('📝 正在更新数据库中的角色信息...');
    const { data: updateResult, error: updateError } = await supabase
      .from('profiles')
      .update(updateData)
      .eq('id', userId)
      .select('id, email, role, nickname')
      .single();

    if (updateError) {
      console.error('❌ 数据库更新失败:', updateError);
      return {
        success: false,
        error: `数据库更新失败: ${updateError.message}`
      };
    }

    console.log('✅ 数据库角色更新成功:', updateResult);

    // 第二步：强制更新JWT中的metadata（关键改进）
    console.log('🔄 正在强制同步JWT metadata...');
    const metadataResult = await forceUpdateJWTMetadata(userId, newRole, {
      database_role: newRole,
      sync_timestamp: new Date().toISOString()
    });

    if (!metadataResult.success) {
      console.warn('⚠️ JWT metadata同步失败，但数据库已更新:', metadataResult.error);
      // 即使metadata同步失败，数据库已经更新，我们仍然可以继续
    }

    // 第三步：再次刷新session确保获取最新的JWT
    console.log('🔄 正在最终刷新JWT Session...');
    const { data: sessionData, error: sessionError } = await supabase.auth.refreshSession();

    if (sessionError) {
      console.error('❌ 最终Session刷新失败:', sessionError);
      // 即使Session刷新失败，数据库已经更新成功
      // 用户可能需要重新登录或稍后自动刷新
      return {
        success: false,
        error: `Session刷新失败: ${sessionError.message}，请尝试重新登录`
      };
    }

    console.log('✅ JWT Session最终刷新成功');

    // 第四步：验证新的Session并获取最新的用户信息
    const updatedUser = await getSession();
    
    if (!updatedUser) {
      return {
        success: false,
        error: '无法获取更新后的用户信息'
      };
    }

    // 验证角色是否已正确更新
    if (updatedUser.role !== newRole) {
      console.warn(`⚠️ 角色更新可能未完全生效: 期望 ${newRole}, 实际 ${updatedUser.role}`);
      // 这种情况可能是由于JWT刷新延迟，通常会在下次Session刷新时生效
    } else {
      console.log('🎉 角色同步验证成功！JWT和数据库角色一致');
    }

    console.log(`🎉 用户角色更新完成: ${updatedUser.role}`);
    console.log(`   用户ID: ${updatedUser.id}`);
    console.log(`   邮箱: ${updatedUser.email}`);
    console.log(`   新角色: ${updatedUser.role}`);

    // 第五步：根据新角色重定向到相应页面
    if (updatedUser.role !== newRole) {
      console.log('🔄 角色可能需要时间同步，稍后将自动重定向...');
      // 延迟重定向，给JWT一些时间完全生效
      setTimeout(() => {
        redirectToRolePath(newRole);
      }, 1000);
    } else {
      // 立即重定向到新角色页面
      redirectToRolePath(updatedUser.role);
    }

    return {
      success: true,
      user: updatedUser
    };

  } catch (error) {
    console.error('❌ 角色更新过程中发生错误:', error);
    return {
      success: false,
      error: `角色更新失败: ${error instanceof Error ? error.message : '未知错误'}`
    };
  }
}

/**
 * 管理员更新其他用户角色的便捷函数
 * 
 * @param targetUserId 目标用户ID
 * @param newRole 新角色
 * @param reason 更新原因（可选，用于审计日志）
 */
export async function adminUpdateUserRole(
  targetUserId: string,
  newRole: UserRole,
  reason?: string
): Promise<{
  success: boolean;
  message?: string;
  error?: string;
}> {
  try {
    console.log(`👑 管理员更新用户角色: ${targetUserId} -> ${newRole}`);
    
    // 验证当前用户是否有管理员权限
    const currentUser = await getSession();
    if (!currentUser) {
      return {
        success: false,
        error: '用户未登录'
      };
    }

    if (!['Master', 'Firstmate'].includes(currentUser.role)) {
      return {
        success: false,
        error: '权限不足，只有Master或Firstmate可以更新用户角色'
      };
    }

    // 调用Supabase函数进行角色更新（这个函数应该在数据库中定义）
    const { data, error } = await supabase.rpc('admin_change_user_role', {
      target_user_id: targetUserId,
      new_role: newRole,
      reason: reason || '管理员手动更新'
    });

    if (error) {
      console.error('❌ 管理员角色更新失败:', error);
      return {
        success: false,
        error: error.message
      };
    }

    console.log('✅ 管理员角色更新成功:', data);
    
    return {
      success: true,
      message: `用户角色已成功更新为 ${newRole}`
    };

  } catch (error) {
    console.error('❌ 管理员角色更新过程中发生错误:', error);
    return {
      success: false,
      error: `角色更新失败: ${error instanceof Error ? error.message : '未知错误'}`
    };
  }
}

/**
 * 示例使用方式：
 * 
 * // 1. 用户自己更新角色（通过邀请链接等方式）
 * const result = await updateUserRoleAndRefreshSession(
 *   'user-uuid-here',
 *   'Member',
 *   { upgrade_reason: 'invite_link_used' }
 * );
 * 
 * if (result.success) {
 *   console.log('角色更新成功！', result.user);
 * } else {
 *   console.error('角色更新失败:', result.error);
 * }
 * 
 * // 2. 管理员更新其他用户角色
 * const adminResult = await adminUpdateUserRole(
 *   'target-user-uuid',
 *   'Seller',
 *   '通过审核，升级为卖家'
 * );
 * 
 * if (adminResult.success) {
 *   console.log(adminResult.message);
 * } else {
 *   console.error(adminResult.error);
 * }
 */

/**
 * 手动同步当前用户的JWT角色信息
 * 当检测到数据库角色与JWT metadata不一致时，可以调用此函数强制同步
 */
export async function syncCurrentUserRole(): Promise<{
  success: boolean;
  oldRole?: string;
  newRole?: string;
  error?: string;
}> {
  if (!browser) {
    return {
      success: false,
      error: '此功能只能在浏览器环境中使用'
    };
  }

  try {
    console.log('🔄 开始同步当前用户角色...');
    
    // 获取当前session
    const { data: { session }, error: sessionError } = await supabase.auth.getSession();
    if (sessionError || !session) {
      return {
        success: false,
        error: '用户未登录或session无效'
      };
    }

    const userId = session.user.id;
    const oldRole = session.user.user_metadata?.role || 'Fan';

    // 从数据库获取最新角色
    const { data: profile, error: profileError } = await supabase
      .from('profiles_public_roles')
      .select('role')
      .eq('id', userId)
      .single();

    if (profileError) {
      return {
        success: false,
        error: `无法获取数据库角色: ${profileError.message}`
      };
    }

    const newRole = profile?.role || 'Fan';

    // 如果角色一致，无需同步
    if (oldRole === newRole) {
      console.log(`✅ 角色已同步: ${newRole}`);
      return {
        success: true,
        oldRole,
        newRole
      };
    }

    console.log(`🔄 检测到角色不一致: JWT=${oldRole}, 数据库=${newRole}`);

    // 强制更新JWT metadata
    const syncResult = await forceUpdateJWTMetadata(userId, newRole as UserRole, {
      sync_reason: 'manual_role_sync',
      previous_role: oldRole
    });

    if (!syncResult.success) {
      return {
        success: false,
        error: syncResult.error,
        oldRole,
        newRole
      };
    }

    console.log(`✅ 角色同步完成: ${oldRole} -> ${newRole}`);
    
    // 重定向到新角色页面
    setTimeout(() => {
      redirectToRolePath(newRole as UserRole);
    }, 500);

    return {
      success: true,
      oldRole,
      newRole
    };

  } catch (error) {
    console.error('❌ 同步用户角色失败:', error);
    return {
      success: false,
      error: `同步失败: ${error instanceof Error ? error.message : '未知错误'}`
    };
  }
}

// 强制刷新用户角色（用于管理员修改角色后的同步）
export async function refreshUserRole(): Promise<User | null> {
  if (!browser) {
    console.log('⚠️ 非浏览器环境，跳过角色刷新');
    return null;
  }

  try {
    console.log('🔄 强制刷新用户角色...');
    
    // 先尝试同步角色
    const syncResult = await syncCurrentUserRole();
    
    if (syncResult.success && syncResult.oldRole !== syncResult.newRole) {
      console.log(`🎯 角色已同步: ${syncResult.oldRole} -> ${syncResult.newRole}`);
    }

    // 返回最新的用户信息
    return await getSession();
    
  } catch (error) {
    console.error('❌ 强制刷新用户角色失败:', error);
    return null;
  }
}

// 角色变更监听器（可在页面中使用）- 包含自动同步功能
export function startRoleChangeListener(intervalMs: number = 30000): () => void {
  if (!browser) {
    console.log('⚠️ 非浏览器环境，无法启动角色监听器');
    return () => {};
  }

  let currentRole: string | null = null;
  let intervalId: NodeJS.Timeout;

  const checkRoleChange = async () => {
    try {
      const user = await getSession();
      
      if (!user) {
        // 用户已登出
        if (currentRole) {
          console.log('👋 角色监听器：检测到用户登出');
          goto('/login');
        }
        currentRole = null;
        return;
      }

      // 初始化当前角色
      if (currentRole === null) {
        currentRole = user.role;
        console.log(`🎯 角色监听器：初始化角色 ${currentRole}`);
        return;
      }

      // 检查角色是否变更
      if (user.role !== currentRole) {
        console.log(`🔄 角色监听器：检测到角色变更 ${currentRole} -> ${user.role}`);
        
        // 尝试同步JWT metadata
        const syncResult = await syncCurrentUserRole();
        if (syncResult.success) {
          console.log(`✅ 角色监听器：角色同步成功 ${syncResult.oldRole} -> ${syncResult.newRole}`);
        }
        
        currentRole = user.role;
        
        // 检查当前页面是否匹配新角色
        const currentPath = window.location.pathname;
        const expectedPath = rolePaths[user.role as UserRole];
        
        if (currentPath !== expectedPath) {
          console.log(`🚀 角色监听器：重定向到新角色页面 ${expectedPath}`);
          redirectToRolePath(user.role as UserRole);
        }
      }
    } catch (error) {
      console.error('❌ 角色监听器：检查角色变更失败:', error);
    }
  };

  // 立即执行一次检查
  checkRoleChange();

  // 设置定期检查
  intervalId = setInterval(checkRoleChange, intervalMs);
  console.log(`🔄 角色监听器：已启动，检查间隔 ${intervalMs}ms`);

  // 返回清理函数
  return () => {
    if (intervalId) {
      clearInterval(intervalId);
      console.log('🛑 角色监听器：已停止');
    }
  };
}
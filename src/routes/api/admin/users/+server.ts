import { json } from '@sveltejs/kit';
import type { RequestHandler } from '@sveltejs/kit';

// 使用统一的API网关域名
const apiBaseUrl = 'https://api.baidaohui.com';

export const GET: RequestHandler = async ({ request, cookies, url }) => {
  try {
    // 获取认证token
    const token = cookies.get('access_token');
    if (!token) {
      return json({ error: '未授权' }, { status: 401 });
    }

    // 获取查询参数
    const role_filter = url.searchParams.get('role');
    const limit = parseInt(url.searchParams.get('limit') || '50');

    // 构建请求参数
    const params = new URLSearchParams();
    if (role_filter) params.append('role_filter', role_filter);
    params.append('limit_count', limit.toString());

    // 调用Supabase函数获取用户列表
    const response = await fetch(`${apiBaseUrl}/rest/v1/rpc/admin_list_users?${params}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
        'apikey': process.env.SUPABASE_ANON_KEY || ''
      },
      body: JSON.stringify({})
    });

    if (!response.ok) {
      const error = await response.json();
      return json(error, { status: response.status });
    }

    const users = await response.json();
    return json({ 
      success: true, 
      users: Array.isArray(users) ? users : [],
      total: Array.isArray(users) ? users.length : 0
    });

  } catch (error) {
    console.error('获取用户列表失败:', error);
    return json({ error: '服务器内部错误' }, { status: 500 });
  }
};

export const PUT: RequestHandler = async ({ request, cookies }) => {
  try {
    // 获取认证token
    const token = cookies.get('access_token');
    if (!token) {
      return json({ error: '未授权' }, { status: 401 });
    }

    const data = await request.json();
    const { userId, email, newRole, reason = '管理员手动调整' } = data;

    // 验证参数
    if (!newRole) {
      return json({ error: '缺少新角色参数' }, { status: 400 });
    }

    if (!userId && !email) {
      return json({ error: '缺少用户标识（userId或email）' }, { status: 400 });
    }

    // 选择使用的函数
    const functionName = userId ? 'admin_change_user_role' : 'admin_change_role_by_email';
    const functionParams = userId ? {
      target_user_id: userId,
      new_role: newRole,
      reason: reason
    } : {
      target_email: email,
      new_role: newRole,
      reason: reason
    };

    // 调用Supabase函数调整角色
    const response = await fetch(`${apiBaseUrl}/rest/v1/rpc/${functionName}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
        'apikey': process.env.SUPABASE_ANON_KEY || ''
      },
      body: JSON.stringify(functionParams)
    });

    if (!response.ok) {
      const error = await response.json();
      return json(error, { status: response.status });
    }

    const result = await response.json();
    
    // 如果成功，标记用户需要重新登录
    if (result.success && result.user_id) {
      try {
        await fetch(`${apiBaseUrl}/rest/v1/rpc/admin_force_user_relogin`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`,
            'apikey': process.env.SUPABASE_ANON_KEY || ''
          },
          body: JSON.stringify({
            target_user_id: result.user_id,
            reason: '角色已更新为 ' + newRole + '，请重新登录获取新权限'
          })
        });
      } catch (err) {
        console.warn('标记重新登录失败:', err);
      }
    }

    return json(result);

  } catch (error) {
    console.error('角色调整失败:', error);
    return json({ error: '服务器内部错误' }, { status: 500 });
  }
};

export const POST: RequestHandler = async ({ request, cookies }) => {
  try {
    // 获取认证token
    const token = cookies.get('access_token');
    if (!token) {
      return json({ error: '未授权' }, { status: 401 });
    }

    const data = await request.json();
    const { action, ...params } = data;

    let functionName: string;
    let functionParams: any;

    switch (action) {
      case 'get_history':
        functionName = 'admin_get_role_change_history';
        functionParams = {
          target_user_id: params.userId || null,
          limit_count: params.limit || 20
        };
        break;

      case 'force_relogin':
        functionName = 'admin_force_user_relogin';
        functionParams = {
          target_user_id: params.userId,
          reason: params.reason || '管理员要求重新登录'
        };
        break;

      default:
        return json({ error: '无效的操作类型' }, { status: 400 });
    }

    // 调用相应的Supabase函数
    const response = await fetch(`${apiBaseUrl}/rest/v1/rpc/${functionName}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
        'apikey': process.env.SUPABASE_ANON_KEY || ''
      },
      body: JSON.stringify(functionParams)
    });

    if (!response.ok) {
      const error = await response.json();
      return json(error, { status: response.status });
    }

    const result = await response.json();
    return json(result);

  } catch (error) {
    console.error('管理员操作失败:', error);
    return json({ error: '服务器内部错误' }, { status: 500 });
  }
}; 
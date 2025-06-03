/**
 * 角色同步工具
 * 解决Supabase与MongoDB之间的角色同步问题
 */

// 扩展Window接口
declare global {
  interface Window {
    supabase?: any;
  }
}

export class RoleSyncManager {
  private issyncing = false;

  /**
   * 强制同步当前用户角色
   */
  async syncCurrentUserRole() {
    if (this.issyncing) {
      console.log('🔄 角色同步正在进行中...');
      return null;
    }

    try {
      this.issyncing = true;
      console.log('🚀 开始强制同步用户角色...');

      // 获取当前用户信息
      const session = await this.getCurrentSession();
      if (!session?.user?.id) {
        throw new Error('未找到有效的用户会话');
      }

      const userId = session.user.id;
      console.log(`🔍 同步用户: ${userId}`);

      // 调用角色同步API
      const response = await fetch('/api/auth/sync-role', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          userId,
          forceSync: true
        })
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || '角色同步失败');
      }

      const result = await response.json();
      console.log('✅ 角色同步成功:', result);

      // 如果token更新了，需要重新加载页面
      if (result.token_updated) {
        console.log('🔄 Token已更新，即将刷新页面...');
        setTimeout(() => {
          window.location.reload();
        }, 1000);
      }

      return result;
    } catch (error) {
      console.error('❌ 角色同步失败:', error);
      throw error;
    } finally {
      this.issyncing = false;
    }
  }

  /**
   * 获取当前Supabase会话
   */
  async getCurrentSession() {
    try {
      // 检查是否有Supabase客户端
      if (typeof window !== 'undefined' && window.supabase) {
        const { data: { session } } = await window.supabase.auth.getSession();
        return session;
      }
      
      // 备用方案：从cookie获取用户信息
      const response = await fetch('/api/auth/validate');
      if (response.ok) {
        const data = await response.json();
        return data.authenticated ? { user: data.user } : null;
      }
      
      return null;
    } catch (error) {
      console.error('获取会话失败:', error);
      return null;
    }
  }

  /**
   * 检查是否需要同步角色
   */
  async checkRoleSyncNeeded() {
    try {
      const session = await this.getCurrentSession();
      if (!session?.user) return false;

      // 从Supabase获取角色
      let supabaseRole = 'Fan';
      try {
        if (window.supabase) {
          const { data, error } = await window.supabase
            .from('profiles')
            .select('role')
            .eq('id', session.user.id)
            .single();
          
          if (!error && data?.role) {
            supabaseRole = data.role;
          }
        }
      } catch (error) {
        console.warn('从Supabase获取角色失败:', error);
      }

      // 从JWT token获取角色
      const jwtRole = session.user.role || 'Fan';

      console.log(`🔍 角色对比: Supabase=${supabaseRole}, JWT=${jwtRole}`);
      
      return supabaseRole !== jwtRole;
    } catch (error) {
      console.error('检查角色同步状态失败:', error);
      return false;
    }
  }

  /**
   * 创建角色同步按钮
   */
  createSyncButton() {
    const button = document.createElement('button');
    button.textContent = '🔄 同步角色';
    button.style.cssText = `
      position: fixed;
      top: 10px;
      right: 10px;
      z-index: 9999;
      padding: 8px 16px;
      background: #ff6b35;
      color: white;
      border: none;
      border-radius: 4px;
      cursor: pointer;
      font-size: 12px;
    `;
    
    button.addEventListener('click', async () => {
      button.disabled = true;
      button.textContent = '🔄 同步中...';
      
      try {
        await this.syncCurrentUserRole();
        button.textContent = '✅ 同步完成';
        setTimeout(() => {
          button.textContent = '🔄 同步角色';
          button.disabled = false;
        }, 2000);
      } catch (error) {
        button.textContent = '❌ 同步失败';
        setTimeout(() => {
          button.textContent = '🔄 同步角色';
          button.disabled = false;
        }, 2000);
        const errorMessage = error instanceof Error ? error.message : String(error);
        alert('角色同步失败: ' + errorMessage);
      }
    });

    return button;
  }

  /**
   * 初始化角色同步管理器
   */
  async init() {
    if (typeof window === 'undefined') return;

    console.log('🎯 角色同步管理器初始化...');

    // 检查是否需要同步
    const needsSync = await this.checkRoleSyncNeeded();
    if (needsSync) {
      console.log('⚠️ 检测到角色不同步，建议手动同步');
      
      // 添加同步按钮到页面
      const syncButton = this.createSyncButton();
      document.body.appendChild(syncButton);
    }

    // 定期检查角色同步状态
    setInterval(() => {
      this.checkRoleSyncNeeded().then(needsSync => {
        if (needsSync) {
          console.log('⚠️ 检测到角色不同步');
        }
      });
    }, 60000); // 每分钟检查一次
  }
}

// 全局实例
export const roleSyncManager = new RoleSyncManager();

// 自动初始化
if (typeof window !== 'undefined') {
  document.addEventListener('DOMContentLoaded', () => {
    roleSyncManager.init();
  });
} 
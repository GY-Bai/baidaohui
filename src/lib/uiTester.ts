/**
 * UI测试工具
 * 批量测试前端组件功能和API调用
 */

interface TestResult {
  name: string;
  status: 'pass' | 'fail' | 'skip';
  message: string;
  duration: number;
}

export class UITester {
  private results: TestResult[] = [];
  private isRunning = false;

  /**
   * 运行所有测试
   */
  async runAllTests() {
    if (this.isRunning) {
      console.log('🔄 测试正在进行中...');
      return;
    }

    this.isRunning = true;
    this.results = [];
    
    console.log('🚀 开始UI批量测试...');
    
    const tests = [
      this.testApiConnectivity.bind(this),
      this.testAuthSystem.bind(this),
      this.testFortuneAPI.bind(this),
      this.testChatAPI.bind(this),
      this.testEmailAPI.bind(this),
      this.testUIComponents.bind(this),
      this.testButtonClicks.bind(this)
    ];

    for (const test of tests) {
      try {
        await test();
      } catch (error) {
        console.error('测试执行失败:', error);
      }
    }

    this.showResults();
    this.isRunning = false;
  }

  /**
   * 测试API连通性
   */
  async testApiConnectivity() {
    const startTime = Date.now();
    try {
      const apiEndpoints = [
        '/api/auth/validate',
        '/api/fortune',
        '/api/chat',
        '/api/email/send',
        '/api/keys'
      ];

      let passCount = 0;
      const testPromises = apiEndpoints.map(async (endpoint) => {
        try {
          const response = await fetch(endpoint, { method: 'GET' });
          // 即使是401也说明API存在
          return response.status !== 404;
        } catch {
          return false;
        }
      });

      const results = await Promise.all(testPromises);
      passCount = results.filter(Boolean).length;

      this.results.push({
        name: 'API连通性测试',
        status: passCount >= apiEndpoints.length * 0.8 ? 'pass' : 'fail',
        message: `${passCount}/${apiEndpoints.length} API端点可访问`,
        duration: Date.now() - startTime
      });
    } catch (error) {
      this.results.push({
        name: 'API连通性测试',
        status: 'fail',
        message: `测试失败: ${error}`,
        duration: Date.now() - startTime
      });
    }
  }

  /**
   * 测试认证系统
   */
  async testAuthSystem() {
    const startTime = Date.now();
    try {
      // 测试token验证
      const response = await fetch('/api/auth/validate');
      const isAuthenticated = response.status === 200;

      this.results.push({
        name: '认证系统测试',
        status: isAuthenticated ? 'pass' : 'skip',
        message: isAuthenticated ? '用户已认证' : '用户未认证（正常）',
        duration: Date.now() - startTime
      });
    } catch (error) {
      this.results.push({
        name: '认证系统测试',
        status: 'fail',
        message: `测试失败: ${error}`,
        duration: Date.now() - startTime
      });
    }
  }

  /**
   * 测试算命API
   */
  async testFortuneAPI() {
    const startTime = Date.now();
    try {
      const endpoints = [
        '/api/fortune/list',
        '/api/fortune/percentile?amount=100&currency=CNY'
      ];

      let passCount = 0;
      for (const endpoint of endpoints) {
        try {
          const response = await fetch(endpoint);
          if (response.status === 200 || response.status === 401) {
            passCount++;
          }
        } catch {
          // 忽略网络错误
        }
      }

      this.results.push({
        name: '算命API测试',
        status: passCount > 0 ? 'pass' : 'fail',
        message: `${passCount}/${endpoints.length} 算命接口可用`,
        duration: Date.now() - startTime
      });
    } catch (error) {
      this.results.push({
        name: '算命API测试',
        status: 'fail',
        message: `测试失败: ${error}`,
        duration: Date.now() - startTime
      });
    }
  }

  /**
   * 测试聊天API
   */
  async testChatAPI() {
    const startTime = Date.now();
    try {
      const endpoints = [
        '/api/chat/members',
        '/api/chat/messages'
      ];

      let passCount = 0;
      for (const endpoint of endpoints) {
        try {
          const response = await fetch(endpoint);
          if (response.status === 200 || response.status === 401) {
            passCount++;
          }
        } catch {
          // 忽略网络错误
        }
      }

      this.results.push({
        name: '聊天API测试',
        status: passCount > 0 ? 'pass' : 'fail',
        message: `${passCount}/${endpoints.length} 聊天接口可用`,
        duration: Date.now() - startTime
      });
    } catch (error) {
      this.results.push({
        name: '聊天API测试',
        status: 'fail',
        message: `测试失败: ${error}`,
        duration: Date.now() - startTime
      });
    }
  }

  /**
   * 测试邮件API
   */
  async testEmailAPI() {
    const startTime = Date.now();
    try {
      // 只测试端点存在性，不实际发送邮件
      const response = await fetch('/api/email/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}) // 空数据，应该返回400
      });

      const isAvailable = response.status === 400 || response.status === 401;

      this.results.push({
        name: '邮件API测试',
        status: isAvailable ? 'pass' : 'fail',
        message: isAvailable ? '邮件接口可用' : '邮件接口不可用',
        duration: Date.now() - startTime
      });
    } catch (error) {
      this.results.push({
        name: '邮件API测试',
        status: 'fail',
        message: `测试失败: ${error}`,
        duration: Date.now() - startTime
      });
    }
  }

  /**
   * 测试UI组件
   */
  async testUIComponents() {
    const startTime = Date.now();
    try {
      const components = [
        'button',
        'input',
        'form',
        'nav',
        'main'
      ];

      let foundCount = 0;
      components.forEach(tag => {
        const elements = document.getElementsByTagName(tag);
        if (elements.length > 0) {
          foundCount++;
        }
      });

      this.results.push({
        name: 'UI组件测试',
        status: foundCount >= components.length * 0.6 ? 'pass' : 'fail',
        message: `${foundCount}/${components.length} 基础组件存在`,
        duration: Date.now() - startTime
      });
    } catch (error) {
      this.results.push({
        name: 'UI组件测试',
        status: 'fail',
        message: `测试失败: ${error}`,
        duration: Date.now() - startTime
      });
    }
  }

  /**
   * 测试按钮点击功能
   */
  async testButtonClicks() {
    const startTime = Date.now();
    try {
      const buttons = document.querySelectorAll('button');
      let workingButtons = 0;
      let totalButtons = Math.min(buttons.length, 10); // 最多测试10个按钮

      for (let i = 0; i < totalButtons; i++) {
        const button = buttons[i] as HTMLButtonElement;
        // 检查按钮是否有点击事件
        const hasOnClick = button.onclick !== null;
        const hasClickAttribute = button.hasAttribute('onclick');
        const hasEventListeners = button.getAttribute('data-has-listeners') === 'true'; // 这需要组件自己标记
        
        if (hasOnClick || hasClickAttribute || hasEventListeners) {
          workingButtons++;
        }
      }

      this.results.push({
        name: '按钮功能测试',
        status: workingButtons > 0 ? 'pass' : 'fail',
        message: `${workingButtons}/${totalButtons} 按钮有事件处理`,
        duration: Date.now() - startTime
      });
    } catch (error) {
      this.results.push({
        name: '按钮功能测试',
        status: 'fail',
        message: `测试失败: ${error}`,
        duration: Date.now() - startTime
      });
    }
  }

  /**
   * 显示测试结果
   */
  showResults() {
    console.log('📊 UI测试结果报告:');
    console.log('='.repeat(50));
    
    let passCount = 0;
    let failCount = 0;
    let skipCount = 0;

    this.results.forEach(result => {
      const icon = result.status === 'pass' ? '✅' : 
                   result.status === 'fail' ? '❌' : '⏭️';
      
      console.log(`${icon} ${result.name}: ${result.message} (${result.duration}ms)`);
      
      if (result.status === 'pass') passCount++;
      else if (result.status === 'fail') failCount++;
      else skipCount++;
    });

    console.log('='.repeat(50));
    console.log(`总计: ${this.results.length} | 通过: ${passCount} | 失败: ${failCount} | 跳过: ${skipCount}`);
    
    // 创建结果面板
    this.createResultsPanel();
  }

  /**
   * 创建测试结果面板
   */
  createResultsPanel() {
    // 移除现有面板
    const existingPanel = document.getElementById('ui-test-results');
    if (existingPanel) {
      existingPanel.remove();
    }

    const panel = document.createElement('div');
    panel.id = 'ui-test-results';
    panel.style.cssText = `
      position: fixed;
      bottom: 10px;
      right: 10px;
      width: 300px;
      max-height: 400px;
      background: white;
      border: 1px solid #ddd;
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
      z-index: 10000;
      font-family: monospace;
      font-size: 12px;
      overflow-y: auto;
    `;

    const header = document.createElement('div');
    header.style.cssText = `
      padding: 12px;
      border-bottom: 1px solid #eee;
      font-weight: bold;
      display: flex;
      justify-content: space-between;
      align-items: center;
    `;
    header.innerHTML = `
      <span>🧪 UI测试结果</span>
      <button onclick="this.parentElement.parentElement.remove()" style="border:none;background:none;cursor:pointer;font-size:16px;">×</button>
    `;

    const content = document.createElement('div');
    content.style.cssText = 'padding: 12px; max-height: 300px; overflow-y: auto;';

    this.results.forEach(result => {
      const item = document.createElement('div');
      item.style.cssText = 'margin-bottom: 8px; padding: 6px; border-radius: 4px; background: #f8f9fa;';
      
      const icon = result.status === 'pass' ? '✅' : 
                   result.status === 'fail' ? '❌' : '⏭️';
      
      item.innerHTML = `
        <div style="font-weight: bold; color: ${result.status === 'pass' ? 'green' : result.status === 'fail' ? 'red' : 'orange'};">
          ${icon} ${result.name}
        </div>
        <div style="margin-top: 2px; color: #666;">
          ${result.message} (${result.duration}ms)
        </div>
      `;
      
      content.appendChild(item);
    });

    panel.appendChild(header);
    panel.appendChild(content);
    document.body.appendChild(panel);
  }

  /**
   * 创建测试按钮
   */
  createTestButton() {
    const button = document.createElement('button');
    button.textContent = '🧪 UI测试';
    button.style.cssText = `
      position: fixed;
      top: 50px;
      right: 10px;
      z-index: 9999;
      padding: 8px 16px;
      background: #28a745;
      color: white;
      border: none;
      border-radius: 4px;
      cursor: pointer;
      font-size: 12px;
    `;
    
    button.addEventListener('click', async () => {
      button.disabled = true;
      button.textContent = '🧪 测试中...';
      
      try {
        await this.runAllTests();
        button.textContent = '✅ 测试完成';
        setTimeout(() => {
          button.textContent = '🧪 UI测试';
          button.disabled = false;
        }, 2000);
      } catch (error) {
        button.textContent = '❌ 测试失败';
        setTimeout(() => {
          button.textContent = '🧪 UI测试';
          button.disabled = false;
        }, 2000);
      }
    });

    return button;
  }
}

// 全局实例
export const uiTester = new UITester();

// 自动初始化
if (typeof window !== 'undefined') {
  document.addEventListener('DOMContentLoaded', () => {
    // 添加测试按钮
    const testButton = uiTester.createTestButton();
    document.body.appendChild(testButton);
  });
} 
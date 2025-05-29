#!/usr/bin/env node

/**
 * 百刀会子目录架构迁移测试脚本
 * 
 * 此脚本用于验证从子域名架构到子目录架构的迁移是否成功
 */

const https = require('https');
const http = require('http');

// 测试配置
const TEST_CONFIG = {
  domain: 'baidaohui.com',
  localhost: 'localhost:3000',
  roles: ['fan', 'member', 'master', 'firstmate', 'seller'],
  testPaths: [
    '/',
    '/login',
    '/fan',
    '/member', 
    '/master',
    '/firstmate',
    '/seller'
  ]
};

// 颜色输出
const colors = {
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  reset: '\x1b[0m'
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

// HTTP请求工具
function makeRequest(url, options = {}) {
  return new Promise((resolve, reject) => {
    const isHttps = url.startsWith('https://');
    const client = isHttps ? https : http;
    
    const requestOptions = {
      method: 'GET',
      timeout: 5000,
      ...options
    };
    
    const req = client.request(url, requestOptions, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          data: data,
          url: url
        });
      });
    });
    
    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });
    
    req.end();
  });
}

// 测试重定向规则
async function testRedirects() {
  log('\n=== 测试重定向规则 ===', 'blue');
  
  const redirectTests = [
    {
      from: `https://fan.${TEST_CONFIG.domain}/`,
      to: `https://${TEST_CONFIG.domain}/fan/`,
      description: 'Fan子域名重定向'
    },
    {
      from: `https://member.${TEST_CONFIG.domain}/`,
      to: `https://${TEST_CONFIG.domain}/member/`,
      description: 'Member子域名重定向'
    },
    {
      from: `https://master.${TEST_CONFIG.domain}/`,
      to: `https://${TEST_CONFIG.domain}/master/`,
      description: 'Master子域名重定向'
    },
    {
      from: `https://firstmate.${TEST_CONFIG.domain}/`,
      to: `https://${TEST_CONFIG.domain}/firstmate/`,
      description: 'Firstmate子域名重定向'
    },
    {
      from: `https://seller.${TEST_CONFIG.domain}/`,
      to: `https://${TEST_CONFIG.domain}/seller/`,
      description: 'Seller子域名重定向'
    },
    {
      from: `https://www.${TEST_CONFIG.domain}/`,
      to: `https://${TEST_CONFIG.domain}/`,
      description: 'WWW重定向'
    }
  ];
  
  for (const test of redirectTests) {
    try {
      const response = await makeRequest(test.from, { 
        method: 'HEAD',
        followRedirect: false 
      });
      
      if (response.statusCode === 301 || response.statusCode === 302) {
        const location = response.headers.location;
        if (location && location.startsWith(test.to.split('?')[0])) {
          log(`✓ ${test.description}: ${test.from} -> ${location}`, 'green');
        } else {
          log(`✗ ${test.description}: 重定向目标不正确 ${location}`, 'red');
        }
      } else {
        log(`✗ ${test.description}: 未返回重定向状态码 (${response.statusCode})`, 'red');
      }
    } catch (error) {
      log(`✗ ${test.description}: 请求失败 - ${error.message}`, 'red');
    }
  }
}

// 测试本地开发环境路由
async function testLocalRoutes() {
  log('\n=== 测试本地路由 ===', 'blue');
  
  for (const path of TEST_CONFIG.testPaths) {
    try {
      const url = `http://${TEST_CONFIG.localhost}${path}`;
      const response = await makeRequest(url);
      
      if (response.statusCode === 200) {
        log(`✓ ${path}: 可访问 (200)`, 'green');
      } else if (response.statusCode === 302 || response.statusCode === 301) {
        const location = response.headers.location;
        log(`→ ${path}: 重定向到 ${location} (${response.statusCode})`, 'yellow');
      } else {
        log(`✗ ${path}: 状态码 ${response.statusCode}`, 'red');
      }
    } catch (error) {
      log(`✗ ${path}: 请求失败 - ${error.message}`, 'red');
    }
  }
}

// 测试API端点
async function testApiEndpoints() {
  log('\n=== 测试API端点 ===', 'blue');
  
  const apiTests = [
    {
      path: '/api/sso/session',
      description: 'SSO会话端点'
    },
    {
      path: '/api/sso/redirect-to-role',
      description: 'SSO角色重定向端点'
    }
  ];
  
  for (const test of apiTests) {
    try {
      const url = `http://${TEST_CONFIG.localhost}${test.path}`;
      const response = await makeRequest(url);
      
      if (response.statusCode < 500) {
        log(`✓ ${test.description}: 端点可访问 (${response.statusCode})`, 'green');
      } else {
        log(`✗ ${test.description}: 服务器错误 (${response.statusCode})`, 'red');
      }
    } catch (error) {
      log(`✗ ${test.description}: 请求失败 - ${error.message}`, 'red');
    }
  }
}

// 测试静态资源
async function testStaticAssets() {
  log('\n=== 测试静态资源 ===', 'blue');
  
  const assetTests = [
    '/favicon.ico',
    '/robots.txt'
  ];
  
  for (const asset of assetTests) {
    try {
      const url = `http://${TEST_CONFIG.localhost}${asset}`;
      const response = await makeRequest(url);
      
      if (response.statusCode === 200) {
        log(`✓ ${asset}: 可访问`, 'green');
      } else if (response.statusCode === 404) {
        log(`- ${asset}: 不存在 (这是正常的)`, 'yellow');
      } else {
        log(`✗ ${asset}: 状态码 ${response.statusCode}`, 'red');
      }
    } catch (error) {
      log(`✗ ${asset}: 请求失败 - ${error.message}`, 'red');
    }
  }
}

// 验证配置文件
function validateConfig() {
  log('\n=== 验证配置文件 ===', 'blue');
  
  const fs = require('fs');
  const path = require('path');
  
  // 检查关键文件
  const criticalFiles = [
    'src/hooks.server.ts',
    'src/lib/auth.ts',
    'services/sso-service/routes.py',
    '_redirects',
    'svelte.config.js'
  ];
  
  for (const file of criticalFiles) {
    try {
      const filePath = path.join(process.cwd(), file);
      if (fs.existsSync(filePath)) {
        log(`✓ ${file}: 存在`, 'green');
        
        // 检查文件内容的关键更新
        const content = fs.readFileSync(filePath, 'utf8');
        
        if (file === 'src/hooks.server.ts') {
          if (content.includes('ROLE_PATH_MAP') && !content.includes('ROLE_SUBDOMAIN_MAP')) {
            log(`  ✓ hooks.server.ts: 已更新为路径映射`, 'green');
          } else {
            log(`  ✗ hooks.server.ts: 仍使用子域名映射`, 'red');
          }
        }
        
        if (file === 'services/sso-service/routes.py') {
          if (content.includes('ROLE_PATHS') && !content.includes('ROLE_SUBDOMAINS')) {
            log(`  ✓ SSO服务: 已更新为路径映射`, 'green');
          } else {
            log(`  ✗ SSO服务: 仍使用子域名映射`, 'red');
          }
        }
        
        if (file === '_redirects') {
          if (content.includes('fan.baidaohui.com') && content.includes('/fan/')) {
            log(`  ✓ 重定向规则: 包含子域名到子目录的重定向`, 'green');
          } else {
            log(`  ✗ 重定向规则: 缺少迁移重定向`, 'red');
          }
        }
        
      } else {
        log(`✗ ${file}: 不存在`, 'red');
      }
    } catch (error) {
      log(`✗ ${file}: 检查失败 - ${error.message}`, 'red');
    }
  }
}

// 主测试函数
async function runTests() {
  log('百刀会子目录架构迁移测试', 'blue');
  log('=====================================', 'blue');
  
  // 验证配置文件
  validateConfig();
  
  // 测试本地路由
  await testLocalRoutes();
  
  // 测试API端点
  await testApiEndpoints();
  
  // 测试静态资源
  await testStaticAssets();
  
  // 如果不是本地环境，测试重定向
  if (process.env.NODE_ENV === 'production') {
    await testRedirects();
  } else {
    log('\n注意: 重定向测试仅在生产环境中运行', 'yellow');
  }
  
  log('\n=== 测试完成 ===', 'blue');
  log('如果所有测试都通过，迁移应该已经成功完成！', 'green');
  log('如果有失败的测试，请检查相应的配置和代码。', 'yellow');
}

// 运行测试
if (require.main === module) {
  runTests().catch(error => {
    log(`测试运行失败: ${error.message}`, 'red');
    process.exit(1);
  });
}

module.exports = {
  runTests,
  testLocalRoutes,
  testApiEndpoints,
  testRedirects,
  validateConfig
}; 
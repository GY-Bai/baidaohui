<script lang="ts">
  import { onMount } from 'svelte';
  import type { PageData } from './$types';

  export let data: PageData;
  
  // 确保数据存在
  $: envCheck = data?.env_check || {};
  $: buildInfo = data?.build_info || {};
  $: backendStatus = data?.backend_status || {};
  $: debugInfo = data?.debug_info || {};
  $: sanJoseVps = backendStatus?.san_jose_vps || {};
  $: buffaloVps = backendStatus?.buffalo_vps || {};
  
  interface ServiceResult {
    status: string;
    error?: string;
    response_time: number;
    http_status?: number;
    service_info?: any;
  }

  interface ServiceConfig {
    name: string;
    url: string;
  }

  let sanJoseResults: Record<string, ServiceResult | null> = {};
  let buffaloResults: Record<string, ServiceResult | null> = {};
  let testing = false;
  let lastTestTime = '';

  // 初始化服务状态
  onMount(() => {
    if (data.service_config) {
      data.service_config.san_jose_services.forEach(service => {
        sanJoseResults[service.name] = null;
      });
      data.service_config.buffalo_services.forEach(service => {
        buffaloResults[service.name] = null;
      });
    }
  });

  // 测试单个服务
  async function testService(url: string): Promise<ServiceResult> {
    const startTime = Date.now();
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 10000); // 10秒超时
    
    try {
      const response = await fetch(url, {
        method: 'GET',
        signal: controller.signal,
        mode: 'cors', // 显式设置CORS模式
        headers: {
          'Accept': 'application/json, text/plain, */*',
          'Cache-Control': 'no-cache'
        }
      });
      
      clearTimeout(timeoutId);
      const responseTime = Date.now() - startTime;
      
      if (response.ok) {
        try {
          const data = await response.json();
          
          // 检查JSON响应中的status字段
          if (data && typeof data === 'object') {
            const serviceStatus = data.status;
            
            if (serviceStatus === 'healthy') {
              return { 
                status: 'healthy', 
                response_time: responseTime,
                http_status: response.status,
                service_info: data
              };
            } else if (serviceStatus) {
              return { 
                status: 'error', 
                error: `服务状态: ${serviceStatus}`, 
                response_time: responseTime,
                http_status: response.status,
                service_info: data
              };
            } else {
              return { 
                status: 'error', 
                error: '响应中缺少status字段', 
                response_time: responseTime,
                http_status: response.status,
                service_info: data
              };
            }
          } else {
            return { 
              status: 'error', 
              error: '无效的JSON响应格式', 
              response_time: responseTime,
              http_status: response.status
            };
          }
        } catch (jsonError) {
          // JSON解析失败，但HTTP状态OK
          try {
            const text = await response.text();
            return { 
              status: 'error', 
              error: `非JSON响应: ${text.substring(0, 100)}`, 
              response_time: responseTime,
              http_status: response.status
            };
          } catch {
            return { 
              status: 'error', 
              error: '无法读取响应内容', 
              response_time: responseTime,
              http_status: response.status
            };
          }
        }
      } else {
        // HTTP错误状态
        try {
          const errorText = await response.text();
          return { 
            status: 'error', 
            error: `HTTP ${response.status}${errorText ? `: ${errorText.substring(0, 50)}` : ''}`, 
            response_time: responseTime,
            http_status: response.status
          };
        } catch {
          return { 
            status: 'error', 
            error: `HTTP ${response.status}`, 
            response_time: responseTime,
            http_status: response.status
          };
        }
      }
    } catch (error: unknown) {
      clearTimeout(timeoutId);
      const responseTime = Date.now() - startTime;
      
      if (error instanceof Error && error.name === 'AbortError') {
        return { status: 'timeout', error: '请求超时', response_time: responseTime };
      }
      
      // 检查是否是CORS错误
      if (error instanceof TypeError && error.message.includes('fetch')) {
        return { 
          status: 'cors_error', 
          error: 'CORS跨域限制或网络错误', 
          response_time: responseTime 
        };
      }
      
      const errorMessage = error instanceof Error ? error.message : String(error);
      return { status: 'error', error: `网络错误: ${errorMessage}`, response_time: responseTime };
    }
  }

  // 运行所有健康检查
  async function runHealthChecks() {
    if (!data.service_config) return;
    
    testing = true;
    lastTestTime = new Date().toLocaleTimeString('zh-CN');
    
    // 清空之前的结果
    sanJoseResults = {};
    buffaloResults = {};
    
    try {
      // 并行测试所有服务
      const [sanJosePromises, buffaloPromises] = [
        data.service_config.san_jose_services.map(async (service: ServiceConfig) => {
          const result = await testService(service.url);
          sanJoseResults[service.name] = result;
          sanJoseResults = { ...sanJoseResults }; // 触发响应式更新
          return { name: service.name, result };
        }),
        data.service_config.buffalo_services.map(async (service: ServiceConfig) => {
          const result = await testService(service.url);
          buffaloResults[service.name] = result;
          buffaloResults = { ...buffaloResults }; // 触发响应式更新
          return { name: service.name, result };
        })
      ];
      
      await Promise.all([...sanJosePromises, ...buffaloPromises]);
    } finally {
      testing = false;
    }
  }

  // 获取状态显示信息
  function getStatusDisplay(result: ServiceResult | null) {
    if (!result) {
      return { icon: '⏳', text: '等待测试', class: 'text-gray-500' };
    }
    
    switch (result.status) {
      case 'healthy':
        return { 
          icon: '✅', 
          text: `正常（HTTP ${result.http_status})`, 
          class: 'text-green-600' 
        };
      case 'timeout':
        return { 
          icon: '⏰', 
          text: '超时', 
          class: 'text-yellow-600' 
        };
      case 'cors_error':
        return { 
          icon: '🚫', 
          text: 'CORS跨域限制', 
          class: 'text-orange-600' 
        };
      default:
        return { 
          icon: '🔴', 
          text: `异常（${result.error})`, 
          class: 'text-red-600' 
        };
    }
  }
</script>

<!-- 版本信息用于强制刷新 -->
<svelte:head>
  <title>系统健康检查 v{buildInfo?.version || '2.3.0'}</title>
  <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
  <meta http-equiv="Pragma" content="no-cache">
  <meta http-equiv="Expires" content="0">
  <meta name="cache-buster" content="{buildInfo?.cache_buster || Date.now()}">
</svelte:head>

<div class="min-h-screen bg-gray-50 py-8">
  <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
    
    <!-- 页面标题 -->
    <div class="text-center mb-8">
      <h1 class="text-3xl font-bold text-gray-900 mb-2">
        系统健康检查面板
      </h1>
      <p class="text-gray-600">
        版本 {buildInfo?.version || '2.3.0'} • 
        {#if lastTestTime}
          最后测试: {lastTestTime}
        {:else}
          点击按钮开始测试
        {/if}
      </p>
      
      <!-- 测试控制按钮 -->
      <div class="mt-4 space-x-4">
        <button 
          on:click={runHealthChecks}
          disabled={testing}
          class="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors text-sm font-medium"
        >
          {#if testing}
            🔄 测试中...
          {:else}
            🚀 开始健康检查
          {/if}
        </button>
        
        {#if lastTestTime}
          <button 
            on:click={runHealthChecks}
            disabled={testing}
            class="px-4 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors text-sm"
          >
            🔄 重新测试
          </button>
        {/if}
      </div>
      
      <!-- 测试模式说明 -->
      <div class="mt-4 p-3 bg-blue-50 rounded-lg border border-blue-200">
        <p class="text-sm text-blue-800">
          💡 <strong>客户端测试模式</strong>：健康检查请求将从您的浏览器发出，绕过Cloudflare Worker限制
        </p>
      </div>
    </div>

    {#if data?.error}
      <!-- 错误状态显示 -->
      <div class="bg-red-50 border-l-4 border-red-400 p-4 mb-6">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"></path>
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-red-800">系统检查异常</h3>
            <p class="mt-1 text-sm text-red-700">{data.error}: {data.message}</p>
          </div>
        </div>
      </div>
    {:else}
      
      <!-- 服务状态监控区 -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        
        <!-- 圣何塞VPS服务状态 -->
        <div class="bg-white rounded-lg shadow-md p-6 border-l-4 border-blue-500">
          <h2 class="text-xl font-semibold text-gray-900 mb-4 flex items-center">
            <span class="w-3 h-3 bg-blue-500 rounded-full mr-3"></span>
            主要API服务
          </h2>
          
          <div class="space-y-2">
            {#each data.service_config.san_jose_services as service}
              {@const result = sanJoseResults[service.name]}
              {@const display = getStatusDisplay(result)}
              <div class="flex items-center justify-between py-1">
                <span class="text-sm font-medium text-gray-700">{service.name}</span>
                <span class="flex items-center text-sm">
                  <span class="mr-1">{display.icon}</span>
                  <span class="{display.class}">{display.text}</span>
                  {#if result?.response_time}
                    <span class="text-gray-500 ml-2 text-xs">({result.response_time}ms)</span>
                  {/if}
                </span>
              </div>
            {/each}
          </div>
          
          {#if Object.keys(sanJoseResults).length === 0}
            <p class="text-gray-500 text-sm">无服务数据</p>
          {/if}
        </div>

        <!-- 水牛城VPS服务状态 -->
        <div class="bg-white rounded-lg shadow-md p-6 border-l-4 border-green-500">
          <h2 class="text-xl font-semibold text-gray-900 mb-4 flex items-center">
            <span class="w-3 h-3 bg-green-500 rounded-full mr-3"></span>
            专门服务
          </h2>
          
          <div class="space-y-2">
            {#each data.service_config.buffalo_services as service}
              {@const result = buffaloResults[service.name]}
              {@const display = getStatusDisplay(result)}
              <div class="flex items-center justify-between py-1">
                <span class="text-sm font-medium text-gray-700">{service.name}</span>
                <span class="flex items-center text-sm">
                  <span class="mr-1">{display.icon}</span>
                  <span class="{display.class}">{display.text}</span>
                  {#if result?.response_time}
                    <span class="text-gray-500 ml-2 text-xs">({result.response_time}ms)</span>
                  {/if}
                </span>
              </div>
            {/each}
          </div>
          
          {#if Object.keys(buffaloResults).length === 0}
            <p class="text-gray-500 text-sm">无服务数据</p>
          {/if}
        </div>
      </div>

      <!-- 系统信息区 -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        
        <!-- 环境变量检查 -->
        <div class="bg-white rounded-lg shadow-md p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">环境配置</h3>
          <div class="space-y-2">
            {#each Object.entries(envCheck) as [key, value]}
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-600">{key}:</span>
                <span class="text-sm font-medium {value === '已设置' || value === '已配置' ? 'text-green-600' : 'text-gray-500'}">
                  {value}
                </span>
              </div>
            {/each}
          </div>
        </div>

        <!-- 构建信息 -->
        <div class="bg-white rounded-lg shadow-md p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">构建信息</h3>
          <div class="space-y-2">
            <div class="flex justify-between">
              <span class="text-sm text-gray-600">版本:</span>
              <span class="text-sm font-medium text-green-600">{buildInfo?.version || '未知'}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-gray-600">模式:</span>
              <span class="text-sm font-medium">{buildInfo?.mode || '未知'}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-gray-600">生产环境:</span>
              <span class="text-sm font-medium">{buildInfo?.is_prod ? '是' : '否'}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-gray-600">SSR:</span>
              <span class="text-sm font-medium">{buildInfo?.is_ssr ? '是' : '否'}</span>
            </div>
          </div>
        </div>

        <!-- 调试信息 -->
        <div class="bg-white rounded-lg shadow-md p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">系统信息</h3>
          <div class="space-y-2">
            <div class="flex justify-between">
              <span class="text-sm text-gray-600">用户代理:</span>
              <span class="text-sm font-medium">{debugInfo?.user_agent || '未知'}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-gray-600">部署环境:</span>
              <span class="text-sm font-medium text-blue-600">{debugInfo?.deployment_env || '未知'}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-gray-600">测试模式:</span>
              <span class="text-sm font-medium text-purple-600">{debugInfo?.testing_mode}</span>
            </div>
          </div>
          {#if debugInfo?.browser_request_note}
            <div class="mt-3 text-xs text-gray-500 italic">
              {debugInfo.browser_request_note}
            </div>
          {/if}
        </div>
      </div>
    {/if}

    <!-- 测试进度指示 -->
    {#if testing}
      <div class="mt-8 bg-blue-50 border border-blue-200 rounded-lg p-4">
        <div class="flex items-center space-x-3">
          <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600"></div>
          <span class="text-blue-800 text-sm font-medium">正在测试后端服务，请稍候...</span>
        </div>
      </div>
    {/if}
  </div>
</div> 
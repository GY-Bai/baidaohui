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
    responseTime: number;
    httpStatus?: number;
    errorType?: string;
    errorMessage?: string;
  }

  interface ServiceConfig {
    name: string;
    url: string;
  }

  let sanJoseResults: Record<string, ServiceResult | null> = {};
  let buffaloResults: Record<string, ServiceResult | null> = {};
  let aiResults: Record<string, ServiceResult | null> = {};
  let testing = false;
  let lastTestTime = '';

  // 初始化服务状态
  onMount(() => {
    if (data.service_config) {
      data.service_config.san_jose_services.forEach((service: ServiceConfig) => {
        sanJoseResults[service.name] = null;
      });
      data.service_config.buffalo_services.forEach((service: ServiceConfig) => {
        buffaloResults[service.name] = null;
      });
      data.service_config.ai_services.forEach((service: ServiceConfig) => {
        aiResults[service.name] = null;
      });
    }
  });

  // 通过代理测试单个服务
  const testService = async (serviceUrl: string): Promise<ServiceResult> => {
    try {
      const proxyUrl = `/api/proxy/health?url=${encodeURIComponent(serviceUrl)}`;
      const response = await fetch(proxyUrl);
      const result = await response.json();
      
      if (!response.ok) {
        return {
          status: 'error',
          responseTime: 0,
          httpStatus: response.status,
          errorMessage: result.message || 'Proxy error'
        };
      }
      
      return {
        status: result.status,
        responseTime: result.responseTime,
        httpStatus: result.httpStatus,
        errorType: result.errorType,
        errorMessage: result.errorMessage
      };
      
    } catch (error: any) {
      return {
        status: 'error',
        responseTime: 0,
        errorMessage: error.message || 'Network error'
      };
    }
  };

  // 运行所有健康检查
  async function runHealthChecks() {
    if (!data.service_config) return;
    
    testing = true;
    lastTestTime = new Date().toLocaleTimeString('zh-CN');
    
    // 清空之前的结果
    sanJoseResults = {};
    buffaloResults = {};
    aiResults = {};
    
    try {
      // 并行测试所有服务
      const [sanJosePromises, buffaloPromises, aiPromises] = [
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
        }),
        data.service_config.ai_services.map(async (service: ServiceConfig) => {
          const result = await testService(service.url);
          aiResults[service.name] = result;
          aiResults = { ...aiResults }; // 触发响应式更新
          return { name: service.name, result };
        })
      ];

      // 等待所有测试完成
      await Promise.allSettled([
        ...sanJosePromises,
        ...buffaloPromises,
        ...aiPromises
      ]);

    } catch (error) {
      console.error('Health check error:', error);
    } finally {
      testing = false;
    }
  }

  // 获取服务状态显示
  function getStatusDisplay(result: ServiceResult | null) {
    if (!result) {
      return '⏳ 待测试';
    }
    
    if (result.status === 'healthy') {
      return `✅ 正常 (${result.responseTime}ms)`;
    }
    
    if (result.status === 'error') {
      if (result.errorType === 'timeout') {
        return `⏰ 超时 (${result.responseTime}ms)`;
      } else if (result.errorType === 'connection_refused') {
        return `🚫 服务离线 (${result.responseTime}ms)`;
      } else if (result.errorType === 'dns_error') {
        return `🌐 DNS解析失败 (${result.responseTime}ms)`;
      } else if (result.errorType === 'forbidden') {
        return `🚫 访问被禁止 (${result.responseTime}ms)`;
      } else if (result.errorType === 'not_found') {
        return `❓ 端点未找到 (${result.responseTime}ms)`;
      } else if (result.errorType === 'server_error') {
        return `💥 服务器错误 (HTTP ${result.httpStatus || '5xx'}, ${result.responseTime}ms)`;
      } else if (result.errorType === 'connection_reset') {
        return `🔌 连接重置 (${result.responseTime}ms)`;
      } else {
        return `🔴 异常 (${result.errorMessage || 'Unknown error'}, ${result.responseTime}ms)`;
      }
    }
    
    return '❓ 未知状态';
  }

  // 获取状态颜色
  function getStatusColor(result: ServiceResult | null) {
    if (!result) return 'text-gray-500';
    
    if (result.status === 'healthy') {
      return 'text-green-600';
    } else {
      return 'text-red-600';
    }
  }
</script>

<!-- 版本信息用于强制刷新 -->
<svelte:head>
  <title>系统健康检查 v{buildInfo?.version || '2.4.0'}</title>
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
        版本 {buildInfo?.version || '2.4.0'} • 
        {#if lastTestTime}
          最后测试: {lastTestTime}
        {:else}
          点击按钮开始测试
        {/if}
      </p>
      
      <!-- 测试控制按钮 -->
      <div class="mt-4">
        <button
          on:click={runHealthChecks}
          disabled={testing}
          class="bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400 text-white font-medium py-2 px-6 rounded-lg transition-colors duration-200"
        >
          {testing ? '测试中...' : '开始健康检查'}
        </button>
      </div>
    </div>

    <!-- 服务状态面板 -->
    <div class="grid gap-6 lg:grid-cols-3">
      
      <!-- 圣何塞VPS (主要服务) -->
      <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
          <span class="w-3 h-3 bg-blue-500 rounded-full mr-2"></span>
          主要API服务
        </h2>
        <p class="text-sm text-gray-600 mb-4">
          圣何塞VPS (api.baidaohui.com)
        </p>
        
        <div class="space-y-3">
          {#if data.service_config?.san_jose_services}
            {#each data.service_config.san_jose_services as service}
              <div class="flex items-center justify-between p-3 bg-gray-50 rounded">
                <span class="font-medium text-gray-900">{service.name}</span>
                <span class="{getStatusColor(sanJoseResults[service.name])} text-sm font-medium">
                  {getStatusDisplay(sanJoseResults[service.name])}
                </span>
              </div>
            {/each}
          {/if}
        </div>
      </div>

      <!-- 水牛城VPS (专门服务) -->
      <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
          <span class="w-3 h-3 bg-green-500 rounded-full mr-2"></span>
          专门服务
        </h2>
        <p class="text-sm text-gray-600 mb-4">
          水牛城VPS (216.144.233.104)
        </p>
        
        <div class="space-y-3">
          {#if data.service_config?.buffalo_services}
            {#each data.service_config.buffalo_services as service}
              <div class="flex items-center justify-between p-3 bg-gray-50 rounded">
                <span class="font-medium text-gray-900">{service.name}</span>
                <span class="{getStatusColor(buffaloResults[service.name])} text-sm font-medium">
                  {getStatusDisplay(buffaloResults[service.name])}
                </span>
              </div>
            {/each}
          {/if}
        </div>
      </div>

      <!-- AI代理服务 -->
      <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
          <span class="w-3 h-3 bg-purple-500 rounded-full mr-2"></span>
          AI代理服务
        </h2>
        <p class="text-sm text-gray-600 mb-4">
          OpenAI兼容API (api.baidaohui.com)
        </p>
        
        <div class="space-y-3">
          {#if data.service_config?.ai_services}
            {#each data.service_config.ai_services as service}
              <div class="flex items-center justify-between p-3 bg-gray-50 rounded">
                <span class="font-medium text-gray-900">{service.name}</span>
                <span class="{getStatusColor(aiResults[service.name])} text-sm font-medium">
                  {getStatusDisplay(aiResults[service.name])}
                </span>
              </div>
            {/each}
          {/if}
        </div>
      </div>

    </div>

    <!-- 环境配置信息 -->
    <div class="mt-8 bg-white rounded-lg shadow-sm border border-gray-200 p-6">
      <h2 class="text-lg font-semibold text-gray-900 mb-4">环境配置</h2>
      
      <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        <div>
          <dt class="text-sm font-medium text-gray-600">构建环境</dt>
          <dd class="mt-1 text-sm text-gray-900">
            {buildInfo?.mode || 'unknown'} 
            {buildInfo?.isDev ? '(开发)' : ''}
            {buildInfo?.isProd ? '(生产)' : ''}
          </dd>
        </div>
        
        <div>
          <dt class="text-sm font-medium text-gray-600">构建时间</dt>
          <dd class="mt-1 text-sm text-gray-900">
            {buildInfo?.timestamp ? new Date(buildInfo.timestamp).toLocaleString('zh-CN') : '未知'}
          </dd>
        </div>
        
        <div>
          <dt class="text-sm font-medium text-gray-600">Supabase连接</dt>
          <dd class="mt-1 text-sm text-gray-900">
            {data.environment?.vite_supabase_url ? '✅ 已配置' : '❌ 未配置'}
          </dd>
        </div>
        
        <div>
          <dt class="text-sm font-medium text-gray-600">应用URL</dt>
          <dd class="mt-1 text-sm text-gray-900">
            {data.environment?.vite_app_url || '未设置'}
          </dd>
        </div>
        
        <div>
          <dt class="text-sm font-medium text-gray-600">运行环境</dt>
          <dd class="mt-1 text-sm text-gray-900">
            {data.environment?.node_env || 'development'}
          </dd>
        </div>
      </div>
    </div>

    <!-- 说明信息 -->
    <div class="mt-6 text-center text-sm text-gray-500">
      <p>
        健康检查通过前端代理进行，避免CORS限制。
        所有API请求现在统一通过 <code class="bg-gray-100 px-1 py-0.5 rounded">api.baidaohui.com</code> 域名访问。
      </p>
      <p class="mt-2">
        AI代理服务提供OpenAI兼容的API接口，支持标准的聊天完成和模型列表功能。
      </p>
    </div>
  </div>
</div> 
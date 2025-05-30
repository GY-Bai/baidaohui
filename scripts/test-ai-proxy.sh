#!/bin/bash

# AI代理服务测试脚本
# 用于验证AI代理服务的各项功能

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
API_BASE="https://api.baidaohui.com"
LOCAL_BASE="http://localhost:5012"
API_KEY="wzj5788@gmail.com"

echo -e "${BLUE}🧪 AI代理服务测试${NC}"
echo "=================================="
echo ""

# 测试函数
test_endpoint() {
    local name="$1"
    local url="$2"
    local method="${3:-GET}"
    local data="$4"
    local headers="$5"
    
    echo -n "测试 ${name}: "
    
    local cmd="curl -s -w '%{http_code}' -X ${method}"
    
    if [ -n "$headers" ]; then
        cmd="$cmd $headers"
    fi
    
    if [ -n "$data" ]; then
        cmd="$cmd -d '$data' -H 'Content-Type: application/json'"
    fi
    
    cmd="$cmd '$url'"
    
    local response
    response=$(eval "$cmd")
    local status_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$status_code" = "200" ] || [ "$status_code" = "201" ]; then
        echo -e "${GREEN}✅ 通过 (${status_code})${NC}"
        return 0
    else
        echo -e "${RED}❌ 失败 (${status_code})${NC}"
        if [ -n "$body" ]; then
            echo "  响应: $body"
        fi
        return 1
    fi
}

# 1. 健康检查测试
echo -e "${YELLOW}1. 健康检查测试${NC}"
test_endpoint "本地健康检查" "${LOCAL_BASE}/health"
test_endpoint "API网关健康检查" "${API_BASE}/v1/health"
echo ""

# 2. 模型列表测试
echo -e "${YELLOW}2. 模型列表测试${NC}"
test_endpoint "本地模型列表" "${LOCAL_BASE}/v1/models" "GET" "" "-H 'Authorization: Bearer ${API_KEY}'"
test_endpoint "API网关模型列表" "${API_BASE}/v1/models" "GET" "" "-H 'Authorization: Bearer ${API_KEY}'"
echo ""

# 3. 聊天完成测试
echo -e "${YELLOW}3. 聊天完成测试${NC}"
chat_data='{
  "model": "gpt-3.5-turbo",
  "messages": [
    {"role": "user", "content": "Hello, world!"}
  ],
  "max_tokens": 50
}'

test_endpoint "本地聊天完成" "${LOCAL_BASE}/v1/chat/completions" "POST" "$chat_data" "-H 'Authorization: Bearer ${API_KEY}'"
test_endpoint "API网关聊天完成" "${API_BASE}/v1/chat/completions" "POST" "$chat_data" "-H 'Authorization: Bearer ${API_KEY}'"
echo ""

# 4. 认证测试
echo -e "${YELLOW}4. 认证测试${NC}"
test_endpoint "无API Key" "${LOCAL_BASE}/v1/models" "GET" "" ""
test_endpoint "错误API Key" "${LOCAL_BASE}/v1/models" "GET" "" "-H 'Authorization: Bearer wrong-key'"
echo ""

# 5. CORS测试
echo -e "${YELLOW}5. CORS测试${NC}"
echo -n "测试CORS头: "
cors_response=$(curl -s -I -X OPTIONS "${LOCAL_BASE}/v1/models" \
  -H "Origin: https://example.com" \
  -H "Access-Control-Request-Method: GET" \
  -H "Access-Control-Request-Headers: Authorization")

if echo "$cors_response" | grep -q "Access-Control-Allow-Origin: \*"; then
    echo -e "${GREEN}✅ CORS配置正确${NC}"
else
    echo -e "${RED}❌ CORS配置错误${NC}"
fi
echo ""

echo "=================================="
echo -e "${BLUE}🎉 测试完成${NC}"
echo ""
echo -e "${YELLOW}💡 使用说明:${NC}"
echo "  API Key: ${API_KEY}"
echo "  本地端点: ${LOCAL_BASE}"
echo "  网关端点: ${API_BASE}"
echo ""
echo -e "${YELLOW}📝 示例请求:${NC}"
echo "curl -X POST '${API_BASE}/v1/chat/completions' \\"
echo "  -H 'Authorization: Bearer ${API_KEY}' \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{"
echo "    \"model\": \"gpt-3.5-turbo\","
echo "    \"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}]"
echo "  }'" 
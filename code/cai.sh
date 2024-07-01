#!/bin/bash

# CMDAI.sh
# 整合了调用DashScope API和执行返回命令的功能

# DashScope API密钥（请使用环境变量或按需修改）
DASHSCOPE_API_KEY="${DASHSCOPE_API_KEY:-sk-xxxx}"
AGENT_NAME="agent_AutoLinuxCMD"
INPUT_JSON="$AGENT_NAME.json"
OUTPUT_JSON="$AGENT_NAME_output.json"
TMP_INPUT_JSON=tmp_"$INPUT_JSON"

# 检查是否提供了用户命令
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 \"your command\""
    exit 1
fi

USER_COMMAND="$1"

# 检查API密钥是否已设置
if [ -z "$DASHSCOPE_API_KEY" ]; then
    echo "Error: DASHSCOPE_API_KEY environment variable is not set."
    exit 1
fi

# 检查输入JSON文件是否存在
if [ ! -f "$INPUT_JSON" ]; then
    echo "Error: Input JSON file not found: $INPUT_JSON"
    exit 1
fi

# 使用jq追加用户指令到指定的JSON文件
jq --arg cmd "$USER_COMMAND" '.input.messages += [{"role": "user", "content": ("callAgent " + $cmd)}]' "$INPUT_JSON" > "$TMP_INPUT_JSON"

# 检查是否成功更新JSON文件
if [ $? -ne 0 ]; then
    echo "Failed to update JSON file."
    exit 1
fi

# 使用curl直接发送请求到DashScope API
curl_response=$(curl --silent --location 'https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation' \
    --header "Authorization: Bearer $DASHSCOPE_API_KEY" \
    --header 'Content-Type: application/json' \
    --data @"$TMP_INPUT_JSON")

# 检查curl响应状态
if [ $? -ne 0 ]; then
    echo "Failed to send request to DashScope API."
    exit 1
fi

# 解析响应并执行命令
last_command=$(echo "$curl_response" | jq -r '.output.choices[0].message.content')
if [ ! -z "$last_command" ]; then
    echo "Executing command: $last_command"
    eval "$last_command"
else
    echo "No assistant command found in the API response."
fi
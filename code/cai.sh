#!/bin/bash

# CMDAI.sh
# 整合了调用DashScope API和执行返回命令的功能，并添加了用户交互

# DashScope API密钥（请使用环境变量或按需修改）
DASHSCOPE_API_KEY="${DASHSCOPE_API_KEY:-YOUR_DEFAULT_KEY}"
AGENT_NAME="agent_AutoLinuxCMD"
INPUT_JSON="$AGENT_NAME.json"
OUTPUT_JSON="$AGENT_NAME_output.json"
TMP_INPUT_JSON="tmp_$INPUT_JSON"

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
jq --arg cmd "$USER_COMMAND" '.input.messages += [{"role": "user", "content": ($cmd)}]' "$INPUT_JSON" > "$TMP_INPUT_JSON"

# 检查是否成功更新JSON文件
if [ $? -ne 0 ]; then
    echo "Failed to update JSON file."
    exit 1
fi

# 函数：执行命令
execute_command() {
    local last_command
    while true; do  # 使用无限循环来重复询问步骤
        # 使用curl发送请求到DashScope API
        curl_response=$(curl -s -X POST 'https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation' \
            -H "Authorization: Bearer $DASHSCOPE_API_KEY" \
            -H 'Content-Type: application/json' \
            --data-binary @"$TMP_INPUT_JSON")

        # 检查curl响应状态
        if [ $? -ne 0 ]; then
            echo "Failed to send request to DashScope API."
            break
        fi

        # 解析响应并获取命令
        last_command=$(echo "$curl_response" | jq -r '.output.choices[0].message.content')
        if [ -z "$last_command" ]; then
            echo "No assistant command found in the API response."
            break  # 如果没有命令，退出循环
        fi

        echo "Received command from API: $last_command"
        read -p "Do you want to execute this command? (y/r/n) " user_choice

        case "$user_choice" in
            [Yy]* )
                echo "Executing command: $last_command"
                eval "$last_command"
                return  # 执行命令后退出函数
                ;;
            [Rr]* )
                echo "Re-fetching command from API..."
                # 循环继续，重新获取命令
                ;;
            [Nn]* )
                echo "Command execution aborted by user."
                return  # 不执行命令并退出函数
                ;;
            * )
                echo "Invalid response. Please answer y, r, or n."
                # 循环继续，等待有效输入
                ;;
        esac
    done
}

# 调用函数执行命令
execute_command
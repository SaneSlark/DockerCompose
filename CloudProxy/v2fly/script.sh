#!/bin/sh
set -e

# 获取环境变量（这些变量在 docker-compose.yml 中定义）
UUID=${UUID}
DOMAIN=${DOMAIN:-example.com}
PORT_BASE=${PORT_BASE:-2275} # V2Ray 实际监听端口

# 1. 启动 V2Ray
echo "Starting V2Ray with configuration from /etc/v2ray/config.json..."
/usr/bin/v2ray run -c /etc/v2ray/config.json &

# 获取 V2Ray 进程 ID
V2RAY_PID=$!

# 2. 确保 V2Ray 启动后输出链接
sleep 3 # 等待 V2Ray 启动

# V2Ray 客户端通常会连接到反向代理（如 Nginx/Caddy）的 443 端口，
# 因此客户端链接中的端口使用 443，域名使用 DOMAIN 变量。
CLIENT_PORT=443

# --- 链接生成部分 ---

# 1. VMess (端口: 2275 -> ${PORT_BASE})
VMESS_JSON=$(cat <<EOM
{
  "v": "2",
  "ps": "Docker-VMess-WS",
  "add": "$DOMAIN",
  "port": "$CLIENT_PORT",
  "id": "$UUID",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "$DOMAIN",
  "path": "/ws",
  "tls": "tls"
}
EOM
)
VMESS_LINK="vmess://$(echo "$VMESS_JSON" | base64 -w 0)"

# 2. VLESS WebSocket (端口: 2276)
VLESS_WS_LINK="vless://$UUID@$DOMAIN:$CLIENT_PORT?encryption=none&security=tls&type=ws&host=$DOMAIN&path=/wss#VLESS-WS"

# 3. VLESS HTTP/2 (端口: 2277)
VLESS_H2_LINK="vless://$UUID@$DOMAIN:$CLIENT_PORT?encryption=none&security=tls&type=h2&host=$DOMAIN&path=/h2#VLESS-H2"

# 4. VLESS QUIC (端口: 2278) - 注意：QUIC通常不走CDN/反代，使用实际端口
VLESS_QUIC_LINK="vless://$UUID@$DOMAIN:$PORT_BASE_4?encryption=none&security=none&type=quic#VLESS-QUIC"

# 5. Trojan WebSocket (端口: 2279)
TROJAN_LINK="trojan://$UUID@$DOMAIN:$CLIENT_PORT?security=tls&type=ws&host=$DOMAIN&path=/tro#Trojan-WS"

echo "======================================================"
echo "✅ V2Ray 核心已启动 (PID: $V2RAY_PID)"
echo "⚠️ 请确保将 替换为您的实际域名/IP"
echo ""
echo "🔗 客户端订阅链接列表:"
echo ""
echo "1. VMess (WS):"
echo "$VMESS_LINK"
echo ""
echo "2. VLESS (WS):"
echo "$VLESS_WS_LINK"
echo ""
echo "3. VLESS (H2):"
echo "$VLESS_H2_LINK"
echo ""
echo "4. VLESS (QUIC - 使用实际端口 $PORT_BASE_4):"
echo "$VLESS_QUIC_LINK"
echo ""
echo "5. Trojan (WS):"
echo "$TROJAN_LINK"
echo "======================================================"

# 3. 保持容器运行
wait $V2RAY_PID
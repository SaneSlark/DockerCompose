#!/bin/sh
set -e

CONFIG_FILE="/etc/v2ray/config.json"
UUID_FILE="/etc/v2ray/uuid.txt"

# UUID格式验证函数
validate_uuid() {
    local uuid="$1"
    # UUID格式正则表达式：8-4-4-4-12的十六进制数字
    local uuid_regex='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    if echo "$uuid" | grep -E "$uuid_regex" >/dev/null 2>&1; then
        return 0  # 格式正确
    else
        return 1  # 格式错误
    fi
}

# 处理UUID逻辑
if [ -n "$UUID" ]; then
    # 检查自定义UUID格式
    if validate_uuid "$UUID"; then
        echo "✅ 使用自定义 UUID: $UUID"
        echo "$UUID" > "$UUID_FILE"
    else
        echo "⚠️  自定义UUID格式不正确，自动生成新的UUID"
        UUID=$(v2ray uuid)
        echo "$UUID" > "$UUID_FILE"
        echo "✅ 生成的 UUID: $UUID"
    fi
elif [ ! -f "$UUID_FILE" ]; then
    # 没有UUID文件和自定义UUID，生成新的
    UUID=$(v2ray uuid)
    echo "$UUID" > "$UUID_FILE"
    echo "✅ 生成的 UUID: $UUID"
else
    # 使用已存在的UUID文件
    UUID=$(cat "$UUID_FILE")
    echo "✅ 使用已存在的 UUID: $UUID"
fi

# 写入 V2Ray 配置
cat > $CONFIG_FILE <<EOF
{
  "inbounds": [
    {
      "port": 2275,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/ws"
        }
      }
    },
    {
      "port": 2276,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "level": 0
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/wss"
        }
      }
    },
    {
      "port": 2277,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "level": 0
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "h2",
        "security": "none",
        "httpSettings": {
          "path": "/h2"
        }
      }
    },
    {
      "port": 2278,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "level": 0
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "quic",
        "security": "none",
        "quicSettings": {
          "security": "none",
          "key": "",
          "header": {
            "type": "none"
          }
        }
      }
    },
    {
      "port": 2279,
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "$UUID",
            "email": "trojan@example.com"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/tro"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "blocked"
      }
    ]
  }
}
EOF

# 输出客户端链接
DOMAIN="${DOMAIN:-example.com}"
VMESS_JSON=$(cat <<EOM
{
  "v": "2",
  "ps": "Docker-VMess-WS",
  "add": "$DOMAIN",
  "port": "443",
  "id": "$UUID",
  "aid": "0",
  "net": "ws",e
  "type": "none",
  "host": "$DOMAIN",
  "path": "/ws",
  "tls": "tls"
}
EOM
)
VMESS_LINK="vmess://$(echo "$VMESS_JSON" | base64 -w 0)"
VLESS_WS_LINK="vless://$UUID@$DOMAIN:443?encryption=none&security=tls&type=ws&host=$DOMAIN&path=/wss#VLESS-WS"
VLESS_H2_LINK="vless://$UUID@$DOMAIN:443?encryption=none&security=tls&type=h2&host=$DOMAIN&path=/h2#VLESS-H2"
VLESS_QUIC_LINK="vless://$UUID@$DOMAIN:443?encryption=none&security=tls&type=quic&host=$DOMAIN#VLESS-QUIC"
TROJAN_LINK="trojan://$UUID@$DOMAIN:443?security=tls&type=ws&host=$DOMAIN&path=/tro#Trojan-WS"

echo "======================================"
echo "✅ 生成的 UUID: $UUID"
echo "🔗 VMess 链接:"
echo "$VMESS_LINK"
echo "🔗 VLESS WebSocket 链接:"
echo "$VLESS_WS_LINK"
echo "🔗 VLESS HTTP/2 链接:"
echo "$VLESS_H2_LINK"
echo "🔗 VLESS QUIC 链接:"
echo "$VLESS_QUIC_LINK"
echo "🔗 Trojan 链接:"
echo "$TROJAN_LINK"
echo "======================================"

# 启动 V2Ray
exec "$@"

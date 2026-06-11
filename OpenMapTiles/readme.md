使用指令（从头到尾完整流程）
在目录 /home/docker/OpenMapTiles 下执行以下命令（按顺序，一步一步来）
第一次部署 / 重新生成地图时
Bash# 1. 确保在正确目录
cd /home/docker/OpenMapTiles

# 2. （可选）先清空旧生成的文件（避免混淆）
rm -f data/osm/china.pmtiles

# 3. 下载最新中国 PBF（如果没有或想更新）
wget -N -P data/osm https://download.geofabrik.de/asia/china-latest.osm.pbf

# 4. 运行生成（会自动下载辅助文件 + 生成 pmtiles）
#    → 这一步最耗时，通常几小时
docker compose -f docker-compose-generate.yml up

# 等它跑完（看到类似 "Done writing PMTiles" 或没有错误退出）

# 5. 确认文件生成成功
ls -lh data/osm/china.pmtiles
# 应该看到一个几十 GB 的文件

# 6. 启动瓦片服务器（后台运行）
docker compose -f docker-compose-serve.yml up -d

# 7. 查看服务器日志（确认加载 china.pmtiles 成功）
docker compose -f docker-compose-serve.yml logs -f tileserver
平时想更新地图（每天/每周一次）
Bashcd /home/docker/OpenMapTiles

# 1. 停止瓦片服务（可选，但推荐，避免文件被占用）
docker compose -f docker-compose-serve.yml down

# 2. 更新 pbf + 重新生成 pmtiles
wget -N -P data/osm https://download.geofabrik.de/asia/china-latest.osm.pbf
docker compose -f docker-compose-generate.yml up

# 3. 重新启动瓦片服务
docker compose -f docker-compose-serve.yml up -d

# 4. 检查是否正常
docker compose -f docker-compose-serve.yml logs --tail 50 tileserver
验证地图是否可用
浏览器打开：
texthttp://你的服务器IP:8080
看到 tileserver-gl 的界面 → 说明成功
在界面上选择 data → 应该能看到 china 数据源 → 选一个风格就能看到中国地图。
常用快捷命令（可以保存成 alias 或脚本）
Bash# 生成新地图
alias gen-map='cd /home/docker/OpenMapTiles && docker compose -f docker-compose-generate.yml up'

# 启动/重启瓦片服务
alias start-map='cd /home/docker/OpenMapTiles && docker compose -f docker-compose-serve.yml up -d'

# 查看日志
alias log-map='cd /home/docker/OpenMapTiles && docker compose -f docker-compose-serve.yml logs -f tileserver'

# 全部停止
alias stop-all='cd /home/docker/OpenMapTiles && docker compose -f docker-compose-serve.yml down && docker compose -f docker-compose-generate.yml down'
这两个文件 + 以上流程，是目前最清晰、最不容易出问题的做法。
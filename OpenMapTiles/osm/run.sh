#!/bin/bash

# 下载中国OSM数据
echo "正在下载中国OSM数据..."
wget https://download.geofabrik.de/asia/china-latest.osm.pbf

# 启动Docker Compose
echo "启动Docker容器..."
docker-compose up
#!/bin/bash

docker run -d \
  --name npc \
  --network host \
  --restart always \
  docker.1ms.run/duan2001/npc:v0.26.47 \
  -server=36.33.27.30:1028 \
  -vkey=3g5s7zcr5dhinb45 \
  -type=tcp
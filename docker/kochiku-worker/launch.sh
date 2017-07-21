#!/bin/bash -l

sed -i "s|kochiku_web_server_host: localhost:3000|kochiku_web_server_host: $KOCHIKUMASTER_PORT_80_TCP_ADDR:$KOCHIKUMASTER_PORT_80_TCP_PORT|" /app/kochiku-worker/config/kochiku-worker.yml
sed -i "s|build_strategy: random|build_strategy: build_all|" /app/kochiku-worker/config/kochiku-worker.yml
sed -i "s|redis_host: localhost|redis_host: $KOCHIKU_REDIS_HOST|" /app/kochiku-worker/config/kochiku-worker.yml
sed -i "s|redis_port: 6379|redis_port: $KOCHIKU_REDIS_PORT|" /app/kochiku-worker/config/kochiku-worker.yml

rake resque:work QUEUES=ci,developerman --require=erb

---
title: docker daemonのdata directoryを変更する
tags: Docker
author: nakamasato
slide: false
---
# DockerのDefaultの data directory

`/var/lib/docker`

# 変更方法

`/etc/docker/daemon.json`に設定を書く

```
vi /etc/docker/daemon.json
```

```json
{
  "data-root": "/mnt/docker-data"
}
```

restart

```
systemctl restart docker
```

# Ref

https://docs.docker.com/engine/daemon/#configuration-file

https://qiita.com/nakamasato/items/b20628546c6e5b32bd8c


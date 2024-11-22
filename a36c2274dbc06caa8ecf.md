---
title: ある特定のportだけ外部に出るトラフィックの帯域を制限する
tags: TC qdisc
author: nakamasato
slide: false
---
# 目標

あるポートで、外に出るトラフィックのみ帯域制限する


# 解決策


```
# DEV=<device>
DEV=eth0
# sudo tc qdisc del dev $DEV root
sudo tc qdisc add dev $DEV root handle 1: htb default 20
sudo tc class add dev $DEV parent 1: classid 1:1 htb rate 1000Mbit ceil 1000Mbit burst 10Mb cburst 10Mb
sudo tc class add dev $DEV parent 1:1 classid 1:10 htb rate 1Kbit ceil 1Kbit burst 1Kb cburst 1Kb
sudo tc class add dev $DEV parent 1:1 classid 1:20 htb rate 800Mbit ceil 1000Mbit burst 10Mb cburst 10Mb
sudo tc filter add dev $DEV protocol ip parent 1:0 prio 1 u32 match ip dport 5044 0xffff flowid 1:10
```

# 解説

Deviceを環境変数に入れておく

```
DEV=eth0
```

qdisc(がある場合は)消す

```
sudo tc qdisc del dev $DEV root
```


qdiscを追加

```
sudo tc qdisc add dev $DEV root handle 1: htb default 20
```

classを追加 (ここで帯域制限のルールを書く)。3つある理由は、一番上がデフォルト、以下でセットするfilterに引っかかる場合を2番目に、3番目は、それ以外という感じでTree構造になってるため。今回は、2行目が大事。

```
sudo tc class add dev $DEV parent 1: classid 1:1 htb rate 1000Mbit ceil 1000Mbit burst 10Mb cburst 10Mb
sudo tc class add dev $DEV parent 1:1 classid 1:10 htb rate 1Kbit ceil 1Kbit burst 1Kb cburst 1Kb
sudo tc class add dev $DEV parent 1:1 classid 1:20 htb rate 800Mbit ceil 1000Mbit burst 10Mb cburst 10Mb
```

filterの設定 `dport 5044` 部分でポート番号を指定

```
sudo tc filter add dev $DEV protocol ip parent 1:0 prio 1 u32 match ip dport 5044 0xffff flowid 1:10
```

上記説明は、結構適当で詳細は http://labs.gree.jp/blog/2014/10/11266/ を参考に。こちらの説明が素晴らしい！


# おまけ

traffic関係で使ったコマンド

```
iftop
```



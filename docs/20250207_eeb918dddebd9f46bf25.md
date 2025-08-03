---
title: bufで他のレポにあるprotoからコード生成
tags: BUF protobuf ProtocolBuffers
author: nakamasato
slide: false
---
## はじめに

Protoファイルを別のレポジトリで管理している時にアプリケーションレポジトリでProtoファイルから生成したコードを使用したい場合があると思います。
その場合に、[buf](https://buf.build/product/cli)を使ってどのように生成するのかを調べました。

## [bufのインストール](https://buf.build/docs/installation/)

Macであればbrewでインストールします。他のインストールはリンクを。

```
$ brew install bufbuild/buf/buf
```

## 設定

```yaml:buf.gen.yaml
version: v2
managed:
  enabled: true
  override:
    - file_option: go_package_prefix
      value: <module>/gen/sample # this makes the package name consistent with your app code
plugins:
  - remote: buf.build/protocolbuffers/go:v1.36.5
    out: gen/sample/ # directory to locate the generated go code
    opt:
      - paths=source_relative
    include_imports: true

inputs:
  - git_repo: ssh://git@github.com/<proto/repo> # git repo for proto
    depth: 1
    tag: v1.0.0 # tag
```

これで`buf generate`を実行すると以下のPathにコードが生成されます。

```
gen/sample/<original path in the proto repo>/
```

アプリケーションコードからも `<module>/gen/sample/xxx` で使いたいpackageを指定して使えます。

特定のPath (`a/b/c` (proto repoのpath))だけに対してコード生成したい場合は以下のように指定することが出来ます。

```
buf generate --path a/b/c
```


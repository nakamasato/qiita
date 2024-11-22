---
title: railsのcallbackに引数を入れる (after_create, before_create, before_build...など)
tags: Rails callback before_action
author: nakamasato
slide: false
---
# 背景
callbackに引数を入れたい


知らないときは、Methodをわざわざ呼んでいた

```rb:app/models/user.rb
class User < ApplicationRecord
  after_create :send_notification

  def send_notification
    send_notification_with_args(%i[name account])
  end
end
```

#解決策

```rb:app/models/user.rb
class User < ApplicationRecord
  after_create -> { send_notification_with_args(%i[name account]) }
end
```

一行ですんだ。


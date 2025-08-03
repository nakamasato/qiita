---
title: rails4+sidekiq+foreman+unicorn+systemd ubuntu 16.04 デプロイ
tags: Rails4 sidekiq foreman unicorn Ubuntu
author: nakamasato
slide: false
---
#背景

sidekiqを利用するとプロセスを複数使うので、foremanで管理すると楽(と思ったが、exportでうまくsystemdのサービスができず結局最後は自分で書いた)。sidekiqの設定は、公式ホームページやRailsCastを参考に。

目標：以前までは、unicorn+capistrano+ubuntuでDeployしていたのをForemanを本番環境で使うようにする！（予定だった）


# foremanのインストールとローカルでの使用方法

## 0. install

```:Gemfile
gem 'foreman'
```
`bundle`でインストール完了

## 1. Procfileを以下のように書く

```:Procfile
redis: redis-server
web: rails s
worker: bundle exec sidekiq
```
## 2. foreman起動

```
foreman start
```

# deployする

参考にするのは、[foremanを使ってRailsのActive Job(Sidekiq)やその他の常駐プロセスの設定をする](http://qiita.com/soramugi/items/b5f099ac1a0bcf555a3a)。



capistrano-foreman (https://github.com/surzycki/capistrano-foreman) を確認

1. `Capfile`に capistrano-foremanを追加

    ```
    require 'capistrano/foreman'
    ```
2. `cap <env> foreman:export`を実行。
    
    `<env>`には、productionの場合には、そのまま`production`と書く。
3. foremanでsystemdをexportするScriptを使うとうまくいかない。
    4. https://github.com/aserafin/capistrano-foreman-systemd にあるので、試してみた（が‥）
    4. PIDFileがserviceに書けない
    5. コマンドが、`/bin/bash -lc '...'`となりこのせいかわからないが、動かない。
    6. 手動で、StartExecとPIDFileを編集すると、スタートできた
    7. 結論：Foremanに頼らず自分でServiceのTemplateを書いてDeployしたほうがいい


## 手動で作る

`foreman export`がしてくれるのは、`Procfile` → Serviceのファイル。 手動で作る場合は、serviceを作るスクリプトとserviceのテンプレートを用意すれば良い。

今回は、sidekiqを例にとってつくる。

1. sidekiq.service.erb
2. sidekiq.target.erb
3. app.target.erb
4. make_service.rake


### sidekiq.service.erb
serviceのテンプレート

```rb:lib/capistrano/templates/sidekiq.erb
[Unit]
PartOf=<%= fetch :application %>.target 

[Service]
SyslogIdentifier=sidekiq-<%= fetch :application %>
User=deploy
WorkingDirectory=<%= current_path %>
Type=forking
PIDFile=<%= current_path %>/tmp/pids/sidekiq.pid
ExecStart=/home/deploy/.rbenv/bin/rbenv exec bundle exec sidekiq -c 5 -e <%= fetch :rails_env %> -P <%= shared_path %>/tmp/pids/sidekiq.pid -d -L log/sidekiq.log >> log/sidekiq.log 2>&1
ExecStop=/home/deploy/.rbenv/bin/rbenv exec bundle exec sidekiqctl stop <%= current_path %>/tmp/pids/sidekiq.pid >> <%= current_path %>/log/sidekiq.log 2>&1

[Install]
WantedBy=multi-user.target
```

### sidekiq.target.erb
sidekiq.targetのテンプレート。targetはService間の関係を表す

```rb:lib/capistrano/templates/sidekiq.target.erb
[Unit]
PartOf=<%= fetch(:application) %>.target
Wants=sidekiq_<%= fetch(:application) %>.service

```


### serviceをデプロイするスクリプト
（foreman_systemdのスクリプトを変更したのでforeman_systemdがそのままになっている）

```rb:make_service.rake
namespace :foreman_systemd do
  desc 'Setup the application services'
  task :setup_service do
    on roles fetch(:foreman_systemd_roles) do
      %w[thrift sidekiq].each do |app_type| ##thriftとsidekiq両方作った 
        service = "#{app_type}_#{fetch(:application)}"
        execute "mkdir -p #{shared_path}/config"
        template "#{app_type}.service.erb", "/tmp/#{app_type}.service"
        dest = "/etc/systemd/system/#{app_type}_#{fetch(:application)}.service"
        sudo "mv /tmp/#{app_type}.service #{dest}"

        template "#{app_type}.target.erb", "/tmp/#{app_type}.target"
        dest = "/etc/systemd/system/#{app_type}_#{fetch(:application)}.target"
        sudo "mv /tmp/#{app_type}.target #{dest}"

        status = capture "sudo systemctl is-enabled #{service} | cat"
        sudo "systemctl enable #{service}" if status == 'disabled'
      end
      template 'app.target.erb', '/tmp/app.target' ＃これで2つのサービスを管理する
      dest = "/etc/systemd/system/#{fetch(:application)}.target"
      sudo "mv /tmp/app.target #{dest}"
      service = "#{fetch(:application)}.target"
      status = capture "sudo systemctl is-enabled #{service} | cat"
      sudo "systemctl enable #{service}" if status == 'disabled'
      sudo 'systemctl daemon-reload'
      sudo "systemctl start #{service}"
    end
  end

  desc 'Start the application services'
  task :start do
    on roles fetch(:foreman_systemd_roles) do
      sudo :systemctl, "start #{fetch(:application)}.target"
    end
  end

  desc 'Stop the application services'
  task :stop do
    on roles fetch(:foreman_systemd_roles) do
      sudo :systemctl, "stop #{fetch(:application)}.target"
    end
  end

  desc 'Restart the application services'
  task :restart do
    on roles fetch(:foreman_systemd_roles) do
      sudo :systemctl, "restart #{fetch(:application)}.target"
    end
  end

end

```



### コマンド

```bash
cap staging foreman_systemd:setup_service
cap staging foreman_systemd:start # start/stop/restart
```

## 問題

foremanはProcfileを変更したときに、コマンドを打つだけで、変更がServiceに更新されて便利だが、自分で書くと、変更を自分で更新しないといけないし、Foremanを使う意味がほぼ無くなる。Procfileを変更してもDevで起動する時に、`foreman start`で起動できるくらいのメリットしかない。



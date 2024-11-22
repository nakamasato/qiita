---
title: railsで複数のRecordをUpdateするrake taskを作る(新カラム作成時など)
tags: Rails rake PostgreSQL
author: nakamasato
slide: false
---
#背景

新しいカラムを追加したが、全てのRecordに同じ値を入れたいわけでもないので`update_all`が使えない。でも全部のRecordを1個ずつ入れるとめちゃくちゃSQLが発行される。

何かいい方法がないか。

#目標設定

既にUserというDBがあって、新しいカラム`sub_id`を追加したとする。

ベタにRakeを書くと以下のようになる。（somethingが一定値の場合は`User.where(条件).update_all(sub_id: <something>)`で済むはずなので、whereが少ない場合は、これを使うのがベスト）

```
User.all.each do |u|
  u.sub_id = <something>
  u.save
end
```
これだと全てのUserに対してFor文が回ってUpdateするのですごいことになる。

# SQLを書いてまとめてUpdate

(id, sub_id)ペアが`(1530, 0), (1531, 1), (1532, 2), (1533, 3), (1534, 4), (1535, 5), (1536, 6), (1537, 7), (1538, 8)`となるものをUpdateする場合。

```sql:test.sql
update users as u set
  sub_id = u2.sub_id
from (values
  (1530, 0), (1531, 1), (1532, 2), (1533, 3), (1534, 4), (1535, 5), (1536, 6), (1537, 7), (1538, 8)
) as u2(id, sub_id)
where u2.id = u.id;
```

```
psql -U <username> -d <db_name> -a -f test.sql
```

で、Recordが更新されていることを確認。

# rakeタスクを作成

今回はAdminが管理するUser(has_many :users)の中でのidを振るというものを例に試してみる

```lib/tasks/update_user_sub_id.rake

namespace :db do
  desc "fill sub_id of users"
  task fill_user_sub_id: :environment do
   Admin.all.each do |a|
      a.users.each_with_index do |u, i|
        u.sub_id = i
      end
      a.save
    end
  end

  task fill_user_sub_id_fast: :environment do
    con = ActiveRecord::Base.connection
    batch_size = 1000
    id_sub_id_pairs = []
    Admin.all.each do |a|
      a.users.order(:id).each_with_index do |u, i|
        id_sub_id_pairs.push "(#{u.id}, #{i})"
        if id_sub_id_pairs.length >= batch_size
          update_sub_id(con, id_sub_id_pairs)
          id_sub_id_pairs = []
        end
      end
    end
    if id_sub_id_pairs.length > 0
      update_sub_id(con, id_sub_id_pairs)
      id_sub_id_pairs = []
    end
  end
end

def update_sub_id(con, id_sub_id_pairs)
  values = id_sub_id_pairs.join ','
  sql = 'UPDATE series AS s '\
        'SET sub_id = s2.sub_id '\
        "FROM (VALUES #{values}) "\
        'AS s2(id, sub_id) '\
        'WHERE s2.id = s.id;'
  con.execute(sql)
end

```


# 速さ比較

```
bundle exec rake db:fill_user_sub_id
...
       user     system      total        real
  3.610000   0.300000   3.910000 (  4.860296)
...
bundle exec rake db:fill_user_sub_id_fast
...
       user     system      total        real
  0.490000   0.080000   0.570000 (  0.757211)
...
```

で合計1000件ほどのRecordで更新を比較してみた。
fastではbatch_sizeを500にしたのでSQLは2個のみで断然速かった




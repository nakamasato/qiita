---
title: Athena(prestoDB)でgroup byしたあとあるカラムの内容を最初のN件だけとってかえすSQL
tags: Athena SQL Presto
author: nakamasato
slide: false
---
# 目標

Group byで、ユーザアカウントしたものの、サンプルとして、いくつかUidsを返したい `limit`してArrayにいれられればいいのだが、残念ながら無い


# 解決策

tableは、

group_columnとuser_idの2つだけの簡単なものでサンプルを以下に記す

```sql
SELECT group_column,
         slice(array_agg(distinct user_id), 1, 2) AS uids, 
         count(distinct user_id) AS cnt
FROM db.my_table
GROUP BY  group_column
ORDER BY  cnt DESC limit 10; 
```

これで


| group_column | uids | cnt |
|:--|:--|--:|
| A | [1, 2] | 10 |
| B | [11, 12] | 6 |
| C | [17, 18] | 4 |

という結果が得られる

# ポイント

```sql
slice(array_agg(distinct user_id), 1, <取りたい数>)
```

## array_agg(x) → array<[same as input]>

aggregate functionの`array_agg`を使って、GroupされたものをArrayにする

## slice(x, start, length) → array

array function の `slice` を使って切る

一番最初から撮りたいときは、startは0ではなく1!!!


## aggregation functionとarray functionの詳細

1. https://prestodb.io/docs/current/functions/aggregate.html
2. https://prestodb.io/docs/current/functions/array.html



---
title: csvからDataを読んでるd3を変数から読むように変更する
tags: d3.js JavaScript CoffeeScript
author: nakamasato
slide: false
---
#背景

d3.jsの例は大体CSVからデータを読む様になっているが、諸事情により、JS内の変数から処理したい


# とりあえずD3を見る

例 [Grouped Bar Chart](https://bl.ocks.org/mbostock/3887051) のJSを [js2.coffee](js2.coffee)で変更した。リンクを開けば、どんなグラフになるか見れる。



```coffeescript
  svg = d3.select('svg')
  margin = 
    top: 20
    right: 20
    bottom: 30
    left: 40
  width = +svg.attr('width') - (margin.left) - (margin.right)
  height = +svg.attr('height') - (margin.top) - (margin.bottom)
  g = svg.append('g').attr('transform', 'translate(' + margin.left + ',' + margin.top + ')')
  x0 = d3.scaleBand().rangeRound([
    0
    width
  ]).paddingInner(0.1)
  x1 = d3.scaleBand().padding(0.05)
  y = d3.scaleLinear().rangeRound([
    height
    0
  ])
  z = d3.scaleOrdinal().range([
    '#98abc5'
    '#8a89a6'
    '#7b6888'
    '#6b486b'
    '#a05d56'
    '#d0743c'
    '#ff8c00'
  ])
  d3.csv 'data.csv', ((d, i, columns) ->
    `var i`
    i = 1
    n = columns.length
    while i < n
      d[columns[i]] = +d[columns[i]]
      ++i
    d
  ), (error, data) ->
    if error
      throw error
    keys = data.columns.slice(1)
    x0.domain data.map((d) ->
      d.State
    )
    x1.domain(keys).rangeRound [
      0
      x0.bandwidth()
    ]
    y.domain([
      0
      d3.max(data, (d) ->
        d3.max keys, (key) ->
          d[key]
      )
    ]).nice()
    g.append('g').selectAll('g').data(data).enter().append('g').attr('transform', (d) ->
      'translate(' + x0(d.State) + ',0)'
    ).selectAll('rect').data((d) ->
      keys.map (key) ->
        {
          key: key
          value: d[key]
        }
    ).enter().append('rect').attr('x', (d) ->
      x1 d.key
    ).attr('y', (d) ->
      y d.value
    ).attr('width', x1.bandwidth()).attr('height', (d) ->
      height - y(d.value)
    ).attr 'fill', (d) ->
      z d.key
    g.append('g').attr('class', 'axis').attr('transform', 'translate(0,' + height + ')').call d3.axisBottom(x0)
    g.append('g').attr('class', 'axis').call(d3.axisLeft(y).ticks(null, 's')).append('text').attr('x', 2).attr('y', y(y.ticks().pop()) + 0.5).attr('dy', '0.32em').attr('fill', '#000').attr('font-weight', 'bold').attr('text-anchor', 'start').text 'Population'
    legend = g.append('g').attr('font-family', 'sans-serif').attr('font-size', 10).attr('text-anchor', 'end').selectAll('g').data(keys.slice().reverse()).enter().append('g').attr('transform', (d, i) ->
      'translate(0,' + i * 20 + ')'
    )
    legend.append('rect').attr('x', width - 19).attr('width', 19).attr('height', 19).attr 'fill', z
    legend.append('text').attr('x', width - 24).attr('y', 9.5).attr('dy', '0.32em').text (d) ->
      d
    return
```

# csvの読まれたデータを見る

データを読んでいるところはここなので、読んだあとの`data`がどうなっているかを見れば良いので、`console.log`などして中身を確認してみる

```
  d3.csv 'data.csv', ((d, i, columns) ->
    `var i`
    i = 1
    n = columns.length
    while i < n
      d[columns[i]] = +d[columns[i]]
      ++i
    d
  ), (error, data) ->
    if error
      throw error
```

```:dataの中身
[Object, Object, Object, Object, Object, Object, columns: Array[8]]
```
は6個のハッシュのようなObjectと何故かcolumnsがKeyのHash型みたいなものが入っている。あとで`data.columns`のところで呼ばれるのが、この部分であることがわかる。前半6個のHash（Object）は、以下のような感じ。

```
5 to 13 Years:4499890
14 to 17 Years:2159981
18 to 24 Years:3853788
25 to 44 Years:10604510
45 to 64 Years:8819342
65 Years and Over:4114496
State:"CA"
Under 5 Years:2704659
```
つまり、1行ずつのデータが`Column名:値`Key-Valueの形になったデータであることがわかる。
最後のColumnsは `["State","Under 5 Years","5 to 13 Years","14 to 17 Years","18 to 24 Years","25 to 44 Years","45 to 64 Years","65 Years and Over"]`である。

# 自分で変数にしてみる

上でdataを解体したので残りは簡単。

簡略化のため簡単なデータを作る。改行も面倒だったので、関数にして動かす。

```coffeescript:変更
# d3.csv 'data.csv', ((d, i, columns) ->
#   `var i`
#   i = 1
#   n = columns.length
#   while i < n
#     d[columns[i]] = +d[columns[i]]
#     ++i
#   d
# ), (error, data) ->
#   if error
#     throw error
test = () ->
  data = [{ 'State': 'Beijing', 'a': 10, 'b': 20, 'c': 30}, {'State': 'Tokyo', 'a': 12, 'b': 10, 'c': 10}]
  data['columns'] = ['State', 'a', 'b', 'c']

# (以下は全部同じ)

test() #これで実行
```

これで、以下のグラフが出来た。

<img width="969" alt="Screen Shot 2017-03-24 at 12.42.28 AM.png" src="https://qiita-image-store.s3.amazonaws.com/0/7059/5545ae98-754c-6f6a-274b-1dc3813d5ea1.png">

これで、自由自在に自分のデータを描画できるようになった。




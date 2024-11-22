# Qiita

https://qiita.com/api/v2/docs


```
cd docs
wget $(curl -s 'https://qiita.com/api/v2/users/nakamasato/items?page=1&per_page=100' | jq -r '[.[].url+".md"]|join(" ")')
wget $(curl -s 'https://qiita.com/api/v2/users/nakamasato/items?page=2&per_page=100' | jq -r '[.[].url+".md"]|join(" ")')
```

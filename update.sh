#!/bin/bash

page=1
while true; do
  items=$(curl -s "https://qiita.com/api/v2/users/nakamasato/items?page=${page}&per_page=100")
  length=$(echo "$items" | jq 'length')
  
  if [ "$length" -eq 0 ]; then
    break
  fi
  
  echo "Processing page ${page} (${length} items)..."
  echo "$items" | jq -r '.[] | .url + ".md"' | xargs -P 10 -I {} curl -s {} -o "docs/$(basename {} .md).md"
  
  page=$((page + 1))
done
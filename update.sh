#!/bin/bash

page=1
while true; do
  items=$(curl -s "https://qiita.com/api/v2/users/nakamasato/items?page=${page}&per_page=100")
  length=$(echo "$items" | jq 'length')
  
  if [ "$length" -eq 0 ]; then
    break
  fi
  
  echo "Processing page ${page} (${length} items)..."
  
  # Process each item individually to extract created_at and id
  echo "$items" | jq -c '.[]' | while read -r item; do
    url=$(echo "$item" | jq -r '.url')
    id=$(echo "$item" | jq -r '.id')
    created_at=$(echo "$item" | jq -r '.created_at')
    
    # Convert created_at to YYYYMMDD format
    date_formatted=$(date -jf "%Y-%m-%dT%H:%M:%S%z" "$created_at" "+%Y%m%d" 2>/dev/null || echo "$created_at" | cut -d'T' -f1 | tr -d '-')
    
    # Download the markdown content
    filename="docs/${date_formatted}_${id}.md"
    echo "Downloading: $url -> $filename"
    curl -s "${url}.md" -o "$filename"
  done
  
  page=$((page + 1))
done
#!/bin/bash

page=1
while true; do
  items=$(curl -s "https://qiita.com/api/v2/users/nakamasato/items?page=${page}&per_page=100")
  length=$(echo "$items" | jq 'length')
  
  if [ "$length" -eq 0 ]; then
    break
  fi
  
  echo "Processing page ${page} (${length} items)..."
  
  # Process each item individually to extract created_at, updated_at and id
  echo "$items" | jq -c '.[]' | while read -r item; do
    url=$(echo "$item" | jq -r '.url')
    id=$(echo "$item" | jq -r '.id')
    created_at=$(echo "$item" | jq -r '.created_at')
    updated_at=$(echo "$item" | jq -r '.updated_at')

    # Convert created_at to YYYYMMDD format
    date_formatted=$(date -jf "%Y-%m-%dT%H:%M:%S%z" "$created_at" "+%Y%m%d" 2>/dev/null || echo "$created_at" | cut -d'T' -f1 | tr -d '-')

    # Check if file needs to be updated
    filename="docs/${date_formatted}_${id}.md"
    should_update=false

    if [ ! -f "$filename" ]; then
      # File doesn't exist, should download
      should_update=true
      echo "New file: $url -> $filename"
    else
      # File exists, check if updated_at is newer than file modification time
      file_mtime=$(stat -f "%m" "$filename" 2>/dev/null || stat -c "%Y" "$filename" 2>/dev/null)
      updated_timestamp=$(date -jf "%Y-%m-%dT%H:%M:%S%z" "$updated_at" "+%s" 2>/dev/null || date -d "$updated_at" "+%s" 2>/dev/null)

      if [ -n "$updated_timestamp" ] && [ -n "$file_mtime" ] && [ "$updated_timestamp" -gt "$file_mtime" ]; then
        should_update=true
        echo "Updated content: $url -> $filename"
      else
        echo "Skipping (no changes): $filename"
      fi
    fi

    # Download the markdown content if needed
    if [ "$should_update" = true ]; then
      curl -s "${url}.md" -o "$filename"
    fi
  done
  
  page=$((page + 1))
done
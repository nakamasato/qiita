---
title: gcloud cheatsheet
tags: GoogleCloud gcloud
author: nakamasato
slide: false
---
# projects

## organization idを取得

```
gcloud projects get-ancestors {projectId}
```

# IAM

## rolesの中身を見る

```
gcloud iam roles describe <rolename>
```

例:

```
gcloud iam roles describe roles/run.developer
```

<details><summary>結果</summary>

```
description: Read and write access to all Cloud Run resources.
etag: AA==
includedPermissions:
- recommender.locations.get
- recommender.locations.list
- recommender.runServiceCostInsights.get
- recommender.runServiceCostInsights.list
- recommender.runServiceCostInsights.update
- recommender.runServiceCostRecommendations.get
- recommender.runServiceCostRecommendations.list
- recommender.runServiceCostRecommendations.update
- recommender.runServiceIdentityInsights.get
- recommender.runServiceIdentityInsights.list
- recommender.runServiceIdentityInsights.update
- recommender.runServiceIdentityRecommendations.get
- recommender.runServiceIdentityRecommendations.list
- recommender.runServiceIdentityRecommendations.update
- recommender.runServicePerformanceInsights.get
- recommender.runServicePerformanceInsights.list
- recommender.runServicePerformanceInsights.update
- recommender.runServicePerformanceRecommendations.get
- recommender.runServicePerformanceRecommendations.list
- recommender.runServicePerformanceRecommendations.update
- recommender.runServiceSecurityInsights.get
- recommender.runServiceSecurityInsights.list
- recommender.runServiceSecurityInsights.update
- recommender.runServiceSecurityRecommendations.get
- recommender.runServiceSecurityRecommendations.list
- recommender.runServiceSecurityRecommendations.update
- resourcemanager.projects.get
- resourcemanager.projects.list
- run.configurations.get
- run.configurations.list
- run.executions.delete
- run.executions.get
- run.executions.list
- run.jobs.create
- run.jobs.delete
- run.jobs.get
- run.jobs.getIamPolicy
- run.jobs.list
- run.jobs.listEffectiveTags
- run.jobs.listTagBindings
- run.jobs.run
- run.jobs.runWithOverrides
- run.jobs.update
- run.locations.list
- run.operations.delete
- run.operations.get
- run.operations.list
- run.revisions.delete
- run.revisions.get
- run.revisions.list
- run.routes.get
- run.routes.invoke
- run.routes.list
- run.services.create
- run.services.delete
- run.services.get
- run.services.getIamPolicy
- run.services.list
- run.services.listEffectiveTags
- run.services.listTagBindings
- run.services.update
- run.tasks.get
- run.tasks.list
name: roles/run.developer
stage: GA
title: Cloud Run Developer
```

</details>



# service

## list services

list with filter

```
gcloud services list --available --project $PROJECT --filter 'aiplatform'
```

## enable service

```
gcloud services enable aiplatform.googleapis.com --project $PROJECT
```

# API Keys

:::note info
API Keyの操作は公式Docに[gcurl](#gcurl)で載っているのでgcurlは下のセクションを参照してください。
:::

## API Key作成

gcloudの場合:

```
gcloud services api-keys create --display-name "Gemini API Key" --project $PROJECT
```

:::note info
APIに制限をつけて作成する場合は、 `--api-target=service=generativelanguage.googleapis.com` などserviceを指定
:::

gcurlの場合:

```
gcurl https://apikeys.googleapis.com/v2/projects/$PROJECT/locations/global/keys -X POST -d '{"displayName" : "Gemini API key"}'
```


## [APIの制限を追加](https://cloud.google.com/api-keys/docs/add-restrictions-api-keys)

gcloudの場合:

```
gcloud services api-keys update \
    projects/$PROJECT/locations/global/keys/$KEY_ID \
    --api-target=service=generativelanguage.googleapis.com
```

gcurlの場合:

```
gcurl https://apikeys.googleapis.com/v2/projects/$PROJECT/locations/global/keys/$KEY_ID\?updateMask\=restrictions \
  --request PATCH \
  --data '{
    "restrictions": {
      "api_targets": [
        {
          "service": "generativelanguage.googleapis.com"
        }
      ]
    },
  }'
```

## Keyの確認

gcloud:

```
gcloud services api-keys list --project $PROJECT --format json | jq ".[] | select(.displayName == \"$DISPLAY_NAME\")"
```

gcurl:

```
gcurl https://apikeys.googleapis.com/v2/projects/$PROJECT/locations/global/keys/$KEY_ID
```

## Keyの削除

```
gcurl https://apikeys.googleapis.com/v2/projects/PROJECT_NUMBER/locations/global/keys/KEY_ID?etag="ETAG" -X DELETE
```

## API Key stringの取得

gcloud:

```
gcloud services api-keys get-key-string projects/$PROJECT/locations/global/keys/$KEY_ID --project $PROJECT
```

gcurl:

```
gcurl https://apikeys.googleapis.com/v2/projects/$PROJECT/locations/global/keys/$KEY_ID/keyString
```

# gcurl

gcloudではなく直接APIを使う場合

```
gcloud auth login
```

```
alias gcurl='curl -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "Content-Type: application/json"'
```

https://cloud.google.com/service-usage/docs/set-up-development-environment


---
title: TerraformでGCP BigQueryのテーブルにtagをつける
tags: GoogleCloud BigQuery
author: nakamasato
slide: false
---
## Overview

タグを定義してResourceにつけることで、Billing上でTagごとに見たり、Tagで権限を管理したりすることができる。

今回はProject内でTagを作成する（OrgやFolderなどでもTagを作成することができる）

## Terraformの定義

### Project data resource

```hcl
data "google_project" "project" {
  project_id = var.project
}
```

### Tag key定義

```hcl
resource "google_tags_tag_key" "pii" {
  parent     = "projects/${data.google_project.project.project_id}"
  short_name = "pii"
}
```

### Tag Value定義

```hcl
# https://cloud.google.com/resource-manager/docs/tags/tags-creating-and-managing#tag-values
resource "google_tags_tag_value" "pii_confidential" {
  parent     = "tagKeys/${google_tags_tag_key.pii.name}"
  short_name = "confidential"
}

resource "google_tags_tag_value" "pii_strictly_confidential" {
  parent     = "tagKeys/${google_tags_tag_key.pii.name}"
  short_name = "strictly_confidential"
}

resource "google_tags_tag_value" "pii_topsecret" {
  parent     = "tagKeys/${google_tags_tag_key.pii.name}"
  short_name = "topsecret"
}
```

### BQのdatasetの定義

```hcl
resource "google_bigquery_dataset" "dataset" {
  dataset_id = "test_dataset"
  project    = var.project
  location   = var.region

  description = "Test iam deny policy"
}

```

### BQのtableの定義

```hcl

resource "google_bigquery_table" "confidential" {
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  table_id   = "confidential"
  project    = var.project

  schema = jsonencode([
    {
      name = "id"
      type = "INTEGER"
      mode = "REQUIRED"
    },
    {
      name = "name"
      type = "STRING"
      mode = "NULLABLE"
    }
  ])

  description = "confidential"
  #   https://cloud.google.com/bigquery/docs/tags#terraform
  resource_tags = {
    (google_tags_tag_key.pii.namespaced_name) : google_tags_tag_value.pii_confidential.short_name,
  }
}
```

## 必要な権限

https://cloud.google.com/bigquery/docs/tags#required_permissions

- roles/resourcemanager.tagUser <- `resourcemanager.tagValueBindings.create` このPermissionが含まれている
- roles/bigtable.admin <- bigquery instanceにタグ付けするときには必要
- roles/bigquery.dataOwner

> To attach tags to Bigtable instances, you need the Bigtable Admin role https://cloud.google.com/bigtable/docs/tags

## Ref

- タグの作成、更新、削除、割当: https://cloud.google.com/resource-manager/docs/tags/tags-creating-and-managing

- タグアクセス管理: https://cloud.google.com/iam/docs/tags-access-control
- タグがサポートされているサービス: https://cloud.google.com/resource-manager/docs/tags/tags-supported-services


## Appendix


### gcloudで確認

まずはProjectとProject numberを環境変数に設定しておく

```
PROJECT=<your project>
PROJECT_NUMBER=$(gcloud projects describe $PROJECT --format="value(projectNumber)")
```

キーのリスト

```
gcloud resource-manager tags keys list --parent=projects/$PROJECT_NUMBER
```
```
NAME                     SHORT_NAME  DESCRIPTION
tagKeys/xxxxxxx          test
```

キーにたいするValueのリスト

上で取得したKeyのNAMEをparentにいれることでkeyがtestのvaluesをリストすることができる

```
gcloud resource-manager tags values list --parent=tagKeys/xxxxxxx
```

```
NAME                       SHORT_NAME             DESCRIPTION
tagValues/xxxxxxxxxxxxxxx  a
tagValues/yyyyyyyyyyyyyyy  b
tagValues/zzzzzzzzzzzzzzz  c
```


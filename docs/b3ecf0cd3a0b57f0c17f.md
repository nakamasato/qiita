---
title: google_artifact_registry_repositoryにはcleanup_policiesをつけよう!
tags: GoogleCloud Terraform ArtifactRegistry
author: nakamasato
slide: false
---
## 問題

artifact registryにdocker imageをPushしていると開発環境などの古いimageがたまり続けてしまう

## cleanup_policies

> Keep policies work with delete policies to keep artifacts that would be deleted according to the specifications of your delete policy, but that you want to keep. When an artifact matches the criteria for both a delete policy and a keep policy, the artifact is kept.

- keepとdeleteのpoliciesをつける
- keepとdelete両頬うにmatchしたらkeepされる

Ref: https://cloud.google.com/artifact-registry/docs/repositories/cleanup-policy


## terraform例

:::note info
terraform-provider-googleの[v4.80.0](https://github.com/hashicorp/terraform-provider-google/releases/tag/v4.80.0)以降を使う必要がある
:::

```hcl
resource "google_artifact_registry_repository" "my-repo" {
  location      = "us-central1"
  repository_id = "my-repository"
  description   = "example docker repository with cleanup policies"
  format        = "DOCKER"
  cleanup_policy_dry_run = false
  cleanup_policies {
    id     = "delete"
    action = "DELETE"
    condition {
      tag_state  = "ANY"      # default: ANY
      older_than = "2592000s" # 30 days
    }
  }
  cleanup_policies {
    id     = "keep-minimum-versions"
    action = "KEEP"
    most_recent_versions {
      keep_count = 5
    }
  }
}
```

Prefixなどで対象を絞ることも可能

## 既存の repositoryの場合

### 既存のRepoの確認

```
gcloud artifacts repositories list --project $PROJECT --location $REGION
```

### option1: terraform import

`terraform import` でterraform管理に変更することができる。

上のtfファイルを記載してから

```
terraform import google_artifact_registry_repository.my-repo projects/{{project}}/locations/{{location}}/repositories/{{repository_id}}
```

という風に実行する

### option2: import blockを使う

terraform 1.5.0 移行であればhttps://developer.hashicorp.com/terraform/language/import blockが使えるので

```hcl
import {
  id = "projects/${var.project}/locations/${var.region}/repositories/cloud-run-source-deploy"
  to = google_artifact_registry_repository.cloud-run-source-deploy
}
```

などと書いて`terraform plan`するとimportするものと変更を確認できる。

```
Plan: 1 to import, 0 to add, 1 to change, 0 to destroy.
```

## apply

plan結果が、cleanup_policies部分のみの差分になっていることを確認してから`terraform apply`を実行

## Ref
1. https://cloud.google.com/artifact-registry/docs/repositories/cleanup-policy
1. https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository#most_recent_versions
1. https://github.com/hashicorp/terraform-provider-google/issues/13824
1. https://github.com/GoogleCloudPlatform/magic-modules/pull/8671
1. https://github.com/hashicorp/terraform-provider-google/releases/tag/v4.80.0


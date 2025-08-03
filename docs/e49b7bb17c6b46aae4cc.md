---
title: [Terraform] deletion_protection = falseのし忘れによるリソース削除時のApply失敗をconftestで防ぐ
tags: Terraform conftest
author: nakamasato
slide: false
---
## はじめに

Terraformでリソースを削除する際、`deletion_protection = false`の設定を忘れてPRを作成し、Planでは問題なく通ったのにApply時に失敗した経験はありませんか？

```
Error: cannot destroy service without setting deletion_protection=false and running `terraform apply`
```

「Planの時に教えてくれよ！」と思うこの問題を、conftestを使って事前に検知する方法を紹介します。

## 課題

Terraformからリソースを削除する際に以下のような問題が発生します：

1. `deletion_protection = false`の設定を忘れたまま(defaultがtrueの場合)削除のPRを作成
2. `terraform plan`では特にエラーが出ない
3. PRをMergeして`terraform apply`を実行
4. Apply時に初めてエラーが発生し、デプロイが失敗

これは特にCloud Run、Cloud SQL、GKEクラスターなど、deletion_protectionがデフォルトで有効になっているGCPリソースでよく発生します。

## 解決策：conftestによる事前チェック

### conftestとは

[conftest](https://www.conftest.dev/)は、構造化データに対してポリシーベースのテストを実行できるツールです。Regoという言語でポリシーを記述し、JSON、YAML、HCLなど様々な形式のデータを検証できます。

Terraformにおいては以下の用途で活用できます：
- Terraformコード自体のポリシーチェック
- **Plan結果に対するポリシーチェック**（今回のケース）

### なぜPlan結果をチェックするのか

今回の問題は、Terraformコードだけでは検知できません。なぜなら：

- `deletion_protection = false`が明示的に設定されている場合は削除可能
- 設定が**なくなっている**場合（デフォルトでtrue）が問題となる

そのため、Plan結果のDiffを確認して、削除されるリソースの`deletion_protection`の状態をチェックする必要があります。

## conftestポリシーの実装

### ユーティルファイル (policy/util.rego)

```rego
package terraform.utils

# Utility functions for Terraform plan analysis

# Check if a resource is being deleted
is_delete(resource) if {
    resource.change.actions[_] == "delete"
}

# Check if a resource is being created
is_create(resource) if {
    resource.change.actions[_] == "create"
}

# Check if a resource is being updated
is_update(resource) if {
    resource.change.actions[_] == "update"
}

# Check if a resource is being replaced
is_replace(resource) if {
    resource.change.actions == ["delete", "create"]
}

# Get the resource type from address
resource_type(resource) := type if {
    parts := split(resource.address, ".")
    type := parts[0]
}

# Get the resource name from address
resource_name(resource) := name if {
    parts := split(resource.address, ".")
    name := parts[1]
}

# Get before values safely
get_before(resource, field) := value if {
    value := resource.change.before[field]
}

# Get after values safely
get_after(resource, field) := value if {
    value := resource.change.after[field]
}

# Check if field is changing
is_field_changing(resource, field) if {
    get_before(resource, field) != get_after(resource, field)
}

# Get all resources of a specific type
resources_of_type(resources, type) := filtered if {
    filtered := [resource |
        resource := resources[_]
        resource_type(resource) == type
    ]
}

# Get resources that are being deleted
resources_being_deleted(resources) := filtered if {
    filtered := [resource |
        resource := resources[_]
        is_delete(resource)
    ]
}
```

### ポリシーファイル（policy/deletion_protection.rego）

```rego
package terraform.gcp.deletion_protection

import rego.v1
import data.terraform.utils

# Resource types that support deletion_protection
deletion_protection_resources := [
    "google_active_directory_domain",
    "google_bigquery_table",
    "google_bigtable_authorized_view",
    "google_bigtable_instance",
    "google_bigtable_logical_view",
    "google_bigtable_materialized_view",
    "google_bigtable_table",
    "google_cloud_run_v2_job",
    "google_cloud_run_v2_service",
    "google_cloud_run_v2_worker_pool",
    "google_compute_instance",
    "google_compute_storage_pool",
    "google_container_cluster",
    "google_dataproc_metastore_federation",
    "google_dataproc_metastore_service",
    "google_folder",
    "google_oracle_database_autonomous_database",
    "google_oracle_database_cloud_exadata_infrastructure",
    "google_oracle_database_cloud_vm_cluster",
    "google_oracle_database_odb_network",
    "google_oracle_database_odb_subnet",
    "google_privateca_certificate_authority",
    "google_secret_manager_regional_secret",
    "google_secret_manager_secret",
    "google_spanner_database",
    "google_sql_database_instance",
    "google_workflows_workflow"
]

# Deny deletion of resources with deletion_protection = true
deny contains msg if {
    # Check all resource changes
    resource := input.resource_changes[_]

    # Check if it's a deletion protection resource type
    resource.type == deletion_protection_resources[_]

    # Check if it's being deleted
    utils.is_delete(resource)

    # Check if deletion_protection = true
    deletion_protection := utils.get_before(resource, "deletion_protection")
    deletion_protection == true

    msg := sprintf(
        "%s '%s' cannot be deleted because deletion_protection is enabled. Set deletion_protection = false before deletion.",
        [resource.type, resource.address]
    )
}
```

### テストファイル（policy/deletion_protection_test.rego）

```rego:
package terraform.gcp.deletion_protection

import rego.v1

# Test: Cloud Run service with deletion protection enabled being deleted (should deny)
test_cloud_run_deletion_protection_deny if {
    deny[_] with input as {
        "resource_changes": [{
            "address": "google_cloud_run_v2_service.test_service",
            "type": "google_cloud_run_v2_service",
            "change": {
                "actions": ["delete"],
                "before": {"deletion_protection": true}
            }
        }]
    }
}

# Test: Resource with deletion protection disabled being deleted (should allow)
test_deletion_protection_allow if {
    count(deny) == 0 with input as {
        "resource_changes": [{
            "address": "google_cloud_run_v2_service.test_service",
            "type": "google_cloud_run_v2_service",
            "change": {
                "actions": ["delete"],
                "before": {"deletion_protection": false}
            }
        }]
    }
}
```

### 設定ファイル（conftest.toml）

```toml
policy = ["policy"]
namespace = "terraform.gcp.deletion_protection"
```


## 実行手順

### 1. Terraform Planの実行とJSON出力

```bash
# バイナリ形式でPlanを出力
terraform plan -no-color -out=tfplan.binary

# JSON形式に変換
terraform show -json tfplan.binary > tfplan.json
```

### 2. conftestによるポリシーチェック

```bash
# ポリシーチェックの実行
conftest test tfplan.json
```

成功時の出力：
```
0 tests, 0 passed, 0 warnings, 0 failures, 0 exceptions
```

失敗時の出力：
```
FAIL - tfplan.json - terraform.gcp.deletion_protection - google_cloud_run_v2_service 'google_cloud_run_v2_service.example' cannot be deleted because deletion_protection is enabled. Set deletion_protection = false before deletion.

2 tests, 1 passed, 0 warnings, 1 failure, 0 exceptions
```

## GitHub Actionsでの自動化

以下のワークフローでPR時に自動チェックを実行できます：


```yaml:.github/workflows/conftest.yaml
name: conftest

on:
  pull_request:
    paths:
      - '**/*.tf'
      - '**/*.tfvars'

jobs:
  policy-check:
    runs-on: ubuntu-latest

    permissions:
      contents: read
      id-token: write
      pull-requests: write

    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Authenticate to Google Cloud
      uses: google-github-actions/auth@v2
      with:
        workload_identity_provider: projects/<project number>/locations/global/workloadIdentityPools/<pool>/providers/<provider>
        service_account: <your sa>@<your project>.iam.gserviceaccount.com
      
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: 1.12.2
        
    - name: Setup aqua
      uses: aquaproj/aqua-installer@v4.0.2
      with:
        aqua_version: v2.53.7

    - name: Install tools with aqua
      run: |
        aqua install
        
    - name: Terraform Init
      run: terraform init
      
    - name: Terraform Plan
      run: |
        terraform plan -no-color -out=tfplan.binary
        terraform show -json tfplan.binary > tfplan.json
        
    - name: Run Conftest
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      run: |
        github-comment exec -k conftest -- conftest test --no-color -c conftest.toml tfplan.json
```

- [github-comment](https://suzuki-shunsuke.github.io/github-comment/) を使うと、conftestの結果を簡単にPR上にコメントとして残すことができます
- conftestやgithub-commentなどのCLIには [aqua](https://aquaproj.github.io/)を使っています

aquaの設定ファイル

```yaml:aqua.yaml
---
# aqua - Declarative CLI Version Manager
# https://aquaproj.github.io/
# checksum:
#   enabled: true
#   require_checksum: true
#   supported_envs:
#   - all
registries:
- type: standard
  ref: v4.396.0 # renovate: depName=aquaproj/aqua-registry
packages:
- name: suzuki-shunsuke/tfcmt@v4.14.9
- name: open-policy-agent/conftest@v0.62.0
- name: suzuki-shunsuke/github-comment@v6.3.4
```

github commentの設定ファイル

```yaml:github-comment.yaml
---
# yaml-language-server: $schema=https://raw.githubusercontent.com/suzuki-shunsuke/github-comment/main/json-schema/github-comment.json
# https://suzuki-shunsuke.github.io/github-comment/
# github-comment works without configuration file. All settings are optional.
skip_no_token: false
# base:
#   org:
#   repo:
vars:
templates:
hide:
  conftest: 'Comment.HasMeta && Comment.Meta.TemplateKey == "conftest" && Comment.Meta.SHA1 != Commit.SHA1'
exec:
  conftest:
    - when: ExitCode != 0
      template: |
        ## Conftest Results

        ❌ Policy Violations Found

        ```
        {{.CombinedOutput | AvoidHTMLEscape}}
        ```
```

## 実際の使用例

### このままでは削除できないコード例

```hcl
resource "google_cloud_run_v2_service" "example" {
  name     = "example-service"
  location = "us-central1"
  
  # deletion_protection = false ← これを忘れている (Defaults to true.)
  
  template {
    containers {
      image = "gcr.io/cloudrun/hello"
    }
  }
}
```

このリソースを削除しようとした場合：

```bash
# リソースをコメントアウトまたは削除
# resource "google_cloud_run_v2_service" "example" { ... }

terraform plan  # 成功する
conftest test --no-color -c conftest.toml tfplan.json  # 失敗する！
```

### 削除ができるコード例

```hcl
resource "google_cloud_run_v2_service" "example" {
  name     = "example-service"
  location = "us-central1"
  
  deletion_protection = false  # これを明示的に設定
  
  template {
    containers {
      image = "gcr.io/cloudrun/hello"
    }
  }
}
```

:::note warn
リソースを削除するには、`deletion_protection = false`のapplyが完了している必要があります。
:::

## まとめ

conftestを使用することで、Terraform Apply時の予期しない失敗を事前に防ぐことができます。

### メリット
- **早期発見**: Plan段階で問題を検知
- **自動化**: CI/CDパイプラインに組み込み可能
- **拡張性**: 他のリソースタイプにも適用可能
- **チーム共有**: ポリシーをコードとして管理・共有

### 応用例
- AWSやAzureリソースへの拡張
- その他のTerraformベストプラクティスのチェック

deletion_protectionの設定忘れに悩まされている方は、ぜひ試してみてください！

## 参考リンク

- [conftest公式ドキュメント](https://www.conftest.dev/)
- [Open Policy Agent (OPA)](https://www.openpolicyagent.org/)
- [Terraform JSON Configuration Syntax](https://www.terraform.io/docs/language/syntax/json.html)
- [github-comment](https://suzuki-shunsuke.github.io/github-comment/)
- [aqua](https://aquaproj.github.io/)


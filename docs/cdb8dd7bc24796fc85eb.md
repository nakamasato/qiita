---
title: Cloud Run のIAP (Pre-GA) をTerraformで設定する
tags: Terraform CloudRun GoogleCloud
author: nakamasato
slide: false
---
## まとめ

- CloudRunのIAPがPre-GAになりました (Apr 7, 2025)
    - *Preview: You can now enable IAP directly on your Cloud Run services without configuring load balancers.* [Release Note #April_07_2025](https://cloud.google.com/release-notes#April_07_2025)
- Terraform google provider 対応 ([v6.31.0](https://github.com/hashicorp/terraform-provider-google/releases/tag/v6.31.0) 以降が必要)
    - [v6.30.0](https://github.com/hashicorp/terraform-provider-google/releases/tag/v6.30.0): cloudrunv2: added `iap_enabled` field to `google_cloud_run_v2_service` resource
 ([#22301](https://github.com/hashicorp/terraform-provider-google/pull/22301))
    - [v6.31.0](https://github.com/hashicorp/terraform-provider-google/releases/tag/v6.31.0): New Resource: `google_iap_web_cloud_run_service_iam_member` ([#22399](https://github.com/hashicorp/terraform-provider-google/pull/22399))


## コード

### IAPを有効化 (projectですでに有効化してあればSkip可)

```hcl
resource "google_project_service" "project" {
  project = "your-project-id"
  service = "iap.googleapis.com"

  disable_on_destroy = false
}
```

### Cloud RunでIAPをEnableする

:::note info
google-beta providerの [v6.30.0](https://github.com/hashicorp/terraform-provider-google-beta/releases/tag/v6.30.0) 以降が必要
:::


```hcl
resource "google_cloud_run_v2_service" "default" {
  provider     = google-beta // necessary for IAP
  name         = "default"
  location     = "asia-northeast1"
  launch_stage = "BETA" // IAP is Pre-GA
  iap_enabled  = true   // enable IAP

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"
    }
  }
}
```

Ref: [cloud_run_v2_service#example-usage---cloudrunv2-service-iap](https://registry.terraform.io/providers/hashicorp/google/6.30.0/docs/resources/cloud_run_v2_service#example-usage---cloudrunv2-service-iap)

### Grant IAP Web permission

:::note info
- google providerの [v6.31.0](https://github.com/hashicorp/terraform-provider-google/releases/tag/v6.31.0) 以降が必要
:::

```hcl
resource "google_iap_web_cloud_run_service_iam_member" "member" {
  project = google_cloud_run_v2_service.default.project
  location = google_cloud_run_v2_service.default.location
  cloud_run_service_name = google_cloud_run_v2_service.default.name
  role = "roles/iap.httpsResourceAccessor"
  member = "user:jane@example.com"
}
```

Ref: [iap_web_cloud_run_service_iam](https://registry.terraform.io/providers/hashicorp/google/6.31.0/docs/resources/iap_web_cloud_run_service_iam)

:::note warn
- applyするには、`roles/iap.admin` role などの `iap.webTypes.getIamPolicy`
と`iap.webTypes.setIamPolicy`の権限が必要[IAP managing access](https://cloud.google.com/iap/docs/managing-access)
:::

applyするSA or Userに `roles/iap.admin` 権限を付与

```hcl
resource "google_project_iam_member" "github_actions" {
  member  = "serviceAccount:xxx@<project>.iam.gserviceaccount.com" # or "user:your@example.com"
  project = "your-project-id"
  role    = "roles/iap.admin"
}
```

## IAPのうしろにあるCloud RunをService Accountから叩く

まず叩くService AccountとCloud RunのEndpointを指定します。Cloud Schedulerから叩く予定であれば、scheduler@<project>.iam.gserviceaccount.com など Cloud Runで使っているservice accountとは別のservice accountを指定する事ができます。

```
SERVICE_ACCOUNT=xxx@<project>.iam.gserviceaccount.com
URL=$(gcloud run services describe default --project <project> --region asia-northeast1 --format json | jq -r '.status.url')
```

次に、jwtを生成するためのclaimを作成します。

```
cat > claim.json << EOM
{
  "iss": "$SERVICE_ACCOUNT",
  "sub": "$SERVICE_ACCOUNT",
  "aud": "$URL",
  "iat": $(date +%s),
  "exp": $((`date +%s` + 3600))
}
EOM
```

サインをしてjwtを発行します。

```
gcloud iam service-accounts sign-jwt --iam-account="$SERVICE_ACCOUNT" claim.json output.jwt
```

最後にendpointをたたいて見ます

```
curl -X POST -H "Authorization: Bearer $(cat output.jwt)" "$URL"
```

:::note warn
audienceの設定は、$URL のみならず、完全なパスを指定する必要があるのでご注意ください。audienceが実際に叩くPathと異なる場合は、Invalid IAP credentials: Audience specified does not match requested endpointというエラーが返ります。
:::

[詳細](https://cloud.google.com/iap/docs/authentication-howto#authenticate_with_an_oidc_token)

## References

- [Configure Identity-Aware Proxy for Cloud Run](https://cloud.google.com/run/docs/securing/identity-aware-proxy-cloud-run)
- [cloud_run_v2_service](https://registry.terraform.io/providers/hashicorp/google/6.30.0/docs/resources/cloud_run_v2_service)
- [iap_web_cloud_run_service_iam](https://registry.terraform.io/providers/hashicorp/google/6.31.0/docs/resources/iap_web_cloud_run_service_iam)
- [【terraform】Cloud RunでIdentity-Aware Proxyを構成できるようになりterraformでも用意してくれた話](https://www.hanachiru-blog.com/entry/2025/04/21/120000)
- [IAP - Programmatic authentication](https://cloud.google.com/iap/docs/authentication-howto#authenticate_with_an_oidc_token)


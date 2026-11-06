# CloudScanner GCP SaaS volume-vetter

Deploys the [volume-vetter](https://github.com/upwindsecurity/terraform-google-integration-modules/tree/main/integrations/cloudscanner/cloudfunction/saasvolumevetter) into a per-customer **SaaS** scanner project: a Cloud Run service behind an Eventarc audit-log trigger that verifies every scan disk the customer's inward-granted service account creates and deletes any that is not validly signed by Upwind's worker.

It is SaaS-only, and complements the scheduled [`../cleaner`](../cleaner): the cleaner removes orphaned disks after the fact, the vetter rejects abusively-created ones at creation time.

## How it works

The worker signs a claim over each scan disk's identity with an Upwind KMS key and stamps the JWS into the disk's description. On every `compute.disks.insert` audit log, a global Eventarc trigger invokes this service, which verifies the signature offline (public key only) and reaps disks created by `customer_sa` that are missing or invalidly signed. See the service's README for the claim and verification detail.

Because GCP has no synchronous admission hook on disk creation, this is a detective control that runs just after the disk exists — not a preventive gate.

## What this module creates

- A **Cloud Run v2 service** running `cloudscanner/saasvolumevetter` as `service_account_email`, with `SIGN_KEY`, `CUSTOMER_SA`, `DRY_RUN` and the log-shipping settings (`UPWIND_REGION` plus the client id/secret sourced from Secret Manager) in its environment. Internal ingress only.
- A **global Eventarc trigger** on `compute.disks.insert` audit logs, delivering to the service as `service_account_email`.
- Optionally (`grant_invoker`, `grant_event_receiver`), the `roles/run.invoker` and `roles/eventarc.eventReceiver` grants the trigger's service account needs. Leave them off where the hub account already holds them.

No KMS grant is made here: the hub account already holds `roles/cloudkms.signerVerifier` on the signing key (from onboarding), which includes `viewPublicKey`. No secret-accessor grant is made either: the vetter runs as the hub account, which already reads the Upwind client credentials through the scaler's grant (as the cleaner does).

## Log shipping

So its verdicts reach Upwind's central logging (and Kibana/OpenSearch), the vetter ships each event's logs to the CloudScanner server over gRPC, with the same Upwind client credentials the scaler/cleaner mount (`client_id_secret` / `client_secret_secret`) and `upwind_infra_region` selecting the backend. This is best-effort telemetry; verification itself never calls the server.

## Usage

```hcl
module "volume_vetter" {
  source = "github.com/upwindsecurity/terraform-google-cloudscanner//modules/volume-vetter"

  project               = "upwind-saas-scanner-abcde"
  name                  = "upwind-volume-vetter-abcde"
  region                = "us-east1"
  service_account_email = "upwind-abcde@hub.iam.gserviceaccount.com"
  sign_key              = "projects/upwind-saas-scanner-abcde/locations/global/keyRings/upwind-cloudscanner/cryptoKeys/scan-volume-sign"
  customer_sa           = "scanner@customer-project.iam.gserviceaccount.com"

  # Log shipping to Upwind's central logging (same secrets the scaler/cleaner use).
  client_id_secret     = "upwind-scanner-client-id-abcde"
  client_secret_secret = "upwind-scanner-client-secret-abcde"
  upwind_infra_region  = "us"

  grant_invoker        = true
  grant_event_receiver = true
  dry_run              = false
}
```

## Inputs

See [`variables.tf`](variables.tf). `dry_run` defaults **true** — a new deletion control starts report-only until the signing rollout is confirmed.

## Prerequisites

The Eventarc and Pub/Sub APIs must be enabled in the project, and their service agents provisioned (onboarding does this). `compute.disks.insert` is an Admin Activity log, always on, so no Data Access audit-log config is required.

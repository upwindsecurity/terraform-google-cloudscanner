# Cloud Scanner deployment preflight

Cloud Scanner deployments often run in constrained enterprise Google Cloud environments where individually valid Terraform inputs can still form an incompatible deployment topology.

The module therefore validates cross-resource assumptions during planning, before Terraform attempts to create or modify Google Cloud resources.

## Validated contracts

The preflight currently verifies that:

- every configured availability zone belongs to the selected region;
- a custom subnet is not supplied without a custom network;
- the Cloud Scanner service account belongs to the configured orchestrator project;
- the scaler service account belongs to the configured orchestrator project;
- when a custom subnet is used, it is attached to the selected custom network.

Failures use a `Cloud Scanner preflight failed` diagnostic that identifies the incompatible values and how to correct the configuration.

## Design principles

The preflight intentionally checks only invariants that can be established with high confidence. It does not attempt to infer organization-policy behavior, internet egress, NAT reachability, or other environment-specific conditions that could create false positives.

Valid configurations do not create additional resources, change resource arguments, or introduce Terraform state solely for preflight validation.

## Testing

The contracts are covered by native `terraform test` cases using mocked Google and null providers. The suite exercises both accepted and rejected configurations without GCP credentials or billable infrastructure.

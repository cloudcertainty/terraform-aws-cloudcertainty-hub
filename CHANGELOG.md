# Changelog

All notable changes to this module are documented here. The module version
tracks the Cloud Certainty Hub release it deploys by default: module version
`X.Y.Z` deploys Hub `X.Y.Z` unless you set `hub_version`. Release candidates
follow the same rule (module `0.1.0-rc.11` deploys Hub `0.1.0-rc.11`).

## 0.1.0-rc.16

- Deploys Cloud Certainty Hub 0.1.0-rc.16 by default: the About and Settings pages link to the
  Hub's own stack in the AWS console (https://cloudcertainty.com/hub/releases/0.1.0-rc.16/). No new
  inputs or outputs.

## 0.1.0-rc.15

- Deploys Cloud Certainty Hub 0.1.0-rc.15 by default: the Hub can adopt product stacks created
  outside it, so it can update and delete them too
  (https://cloudcertainty.com/hub/releases/0.1.0-rc.15/).
- New input `adoptable_stacks` (default `[]`): names of existing product stacks, not named with
  `stack_name_prefix`, that the Hub may adopt. IAM allows the Hub on these names too. Left out of
  the stack's parameters when empty, so older Hub releases still deploy. It must not list
  `stack_name`.

## 0.1.0-rc.14

- Deploys Cloud Certainty Hub 0.1.0-rc.14 by default: product logos on the Products page and a
  link to each product's demo video (https://cloudcertainty.com/hub/releases/0.1.0-rc.14/). No new
  inputs or outputs.

## 0.1.0-rc.13

- Deploys Cloud Certainty Hub 0.1.0-rc.13 by default: the Hub checks the AWS Marketplace
  subscription before installing a product that needs one, and explains how to recover from a
  failed first install (https://cloudcertainty.com/hub/releases/0.1.0-rc.13/). No new inputs or
  outputs.

## 0.1.0-rc.12

- Deploys Cloud Certainty Hub 0.1.0-rc.12 by default: a sign-in page in the Hub's own style and a
  Stay informed section for product update and newsletter emails
  (https://cloudcertainty.com/hub/releases/0.1.0-rc.12/). No new inputs or outputs.

## 0.1.0-rc.11

- First release: deploys Cloud Certainty Hub 0.1.0-rc.11 by default (`hub_version`) into your
  AWS account through its CloudFormation template, as a single `aws_cloudformation_stack`.
  `hub_version` selects the template; `template_url` defaults to the vendor's public us-east-1
  bucket (`https://cloudcertainty-hub-us-east-1.s3.us-east-1.amazonaws.com/<hub_version>/main.yaml`)
  whatever the deploy Region.
- The stack is tagged `cloudcertainty:managed-by = terraform`, so the Hub never updates itself:
  its About page and update reminders say which `hub_version` to set instead, and Terraform state
  never drifts. The tag cannot be overridden through `tags`.
- Sign-in: `identity_provider` takes `IAMIdentityCenter` (default), `SAML`, `OIDC` (client secret
  read from Secrets Manager by ARN) or `CognitoOnly`. `identity_center_setup` (`CreateIfMissing`,
  `UseExisting`, `Disabled`) and `identity_center_region` set up IAM Identity Center in the
  account and the `CloudCertaintyHubAdmins` group with a user for `bootstrap_admin_email`.
- Installing products: `deploy_mode` (`Full`, or `ExportOnly` to export Terraform and
  CloudFormation only), `stack_name_prefix` (the Hub only manages product stacks whose names start
  with it) and `catalogue_url`.
- Update reminders: `update_reminders` (`Enabled` by default) emails `update_notification_email`
  (or `bootstrap_admin_email` when empty) when a newer Hub release exists, then 1, 3, 7 and 30 days
  later and every 30 days until the Hub is updated. Output `update_topic_arn` for more subscribers.
- Also `name_prefix`, `stack_name` (default `cloudcertainty-hub`), `tags` (Owner, CostCenter and
  Environment also feed the template's tag parameters), `log_retention_days`, `kms_key_arn`,
  `cloudformation_role_arn`, `timeout` and the support-only `artifact_version_override`.
- Plan-time checks mirror the template's rules: OIDC needs its three settings,
  `saml_metadata_url` is only used with `IAMIdentityCenter` or `SAML`, and `stack_name` must not
  start with `stack_name_prefix`. `hub_version`, `name_prefix`, `identity_provider`,
  `identity_center_setup`, `identity_center_region`, `deploy_mode`, `update_reminders` and the two
  email inputs are validated against the template's allowed values and patterns.

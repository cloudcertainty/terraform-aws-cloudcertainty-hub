# Cloud Certainty Hub: Terraform module

Deploy [Cloud Certainty Hub](https://cloudcertainty.com/hub/) into your own AWS account with Terraform or OpenTofu.

**Links:** [Product page](https://cloudcertainty.com/hub/) · [Getting started](https://cloudcertainty.com/hub/docs/getting-started/)

Cloud Certainty Hub is free and runs entirely in your account. It is one place to manage every Cloud Certainty product:
- See every product, and subscribe to it on AWS Marketplace.
- Install a product by filling in its parameters in a form, update it to the latest release, or export the same install as Terraform or CloudFormation.
- Set up AWS IAM Identity Center in the account (or use the one you have), with a `CloudCertaintyHubAdmins` group whose members are Hub administrators.
- Let users sign in through the Hub: every product installed through it can use the Hub's sign-in (single sign-on).

Nothing leaves your account: the Hub only reads Cloud Certainty's public catalogue, release manifests and templates.

This module deploys the Hub's official CloudFormation template as a single `aws_cloudformation_stack`. The template is the same one you would launch from the CloudFormation console, at the release you pin with `hub_version`. The module adds plan-time validation and Terraform-friendly inputs and outputs.

**Any Region.** Configure the AWS provider for the Region you want the Hub in. The template is always read from the vendor's public bucket in us-east-1 (`https://cloudcertainty-hub-us-east-1.s3.us-east-1.amazonaws.com/<hub_version>/main.yaml`), which CloudFormation accepts for a stack in any Region.

**Terraform owns the stack.** The module tags the stack `cloudcertainty:managed-by = terraform`. The Hub reads that tag and never updates itself, so Terraform state never drifts: you update the Hub by raising the module version (see [Staying up to date](#staying-up-to-date)).

## Prerequisites

1. **Permissions.** The identity running Terraform needs permission to create the stack's resources, including named IAM roles. Alternatively, pass a CloudFormation service role in `cloudformation_role_arn`. With `identity_center_setup = "CreateIfMissing"` (the default), the stack also finds or creates IAM Identity Center in the account.
2. **Versions.** Terraform >= 1.5 (or OpenTofu) and the AWS provider v6.

No AWS Marketplace subscription is needed for the Hub itself. Each product you install through the Hub has its own listing, which the Hub links to.

## Usage

```hcl
module "hub" {
  source  = "cloudcertainty/cloudcertainty-hub/aws"
  version = "0.1.0-rc.18"

  identity_provider     = "IAMIdentityCenter"
  bootstrap_admin_email = "it-admin@acme.com"

  tags = {
    Owner       = "platform-team"
    CostCenter  = "1234"
    Environment = "prod"
  }
}

output "portal_url" {
  value = module.hub.portal_url
}
```

**Release candidates need an exact version.** Terraform only selects a pre-release such as `0.1.0-rc.18` when `version` names it exactly (`version = "0.1.0-rc.18"`); a range such as `~> 0.1` never matches it. Once a final release is out, `version = "~> 0.1.0"` or an exact version both work.

Open `portal_url` and sign in as `bootstrap_admin_email`.

### Signing in with AWS IAM Identity Center

With `identity_center_setup = "CreateIfMissing"` (the default) the stack uses the account's IAM Identity Center, or creates an account instance when there is none (in `identity_center_region`, else the provider's Region). When the account owns it, the stack also creates the `CloudCertaintyHubAdmins` group with a user for `bootstrap_admin_email`. `UseExisting` fails the stack when there is no IAM Identity Center; `Disabled` leaves it alone. Nothing is ever deleted. The `identity_center_status` output says what the setup did, or why it could not (for example in an organisation's management account, where IAM Identity Center is enabled from the console).

AWS doesn't let IAM Identity Center custom SAML applications be created as code, so sign-in takes two applies:

1. `terraform apply` with `saml_metadata_url` left empty.
2. In IAM Identity Center (in the Region of the `identity_center_region` output), choose **Applications → Add application → I have an application I want to set up → SAML 2.0**:
   - **Display name:** `Cloud Certainty Hub`; copy the **IAM Identity Center SAML metadata file** URL.
   - **Application start URL:** the `portal_url` output.
   - **Application ACS URL:** the `saml_acs_url` output.
   - **Application SAML audience:** the `saml_audience_uri` output.
   - **Attribute mappings:** `Subject` → `${user:email}` (format `emailAddress`), `email` → `${user:email}` and `groups` → `${user:groups}`.
   - Assign users or groups, including the `CloudCertaintyHubAdmins` group.
3. Set `saml_metadata_url` to the metadata URL and run `terraform apply` again.

The Hub's Identity Center page shows the same values. See [examples/iam-identity-center](examples/iam-identity-center) and the [getting started guide](https://cloudcertainty.com/hub/docs/getting-started/).

Use the same steps for any SAML 2.0 identity provider with `identity_provider = "SAML"`.

### Signing in with OIDC (Entra ID, Okta, Google Workspace, …)

Create the client secret in Secrets Manager **outside Terraform**, so it never appears in Terraform state. Then pass its ARN:

```hcl
data "aws_secretsmanager_secret" "oidc" {
  name = "cloudcertainty-hub/oidc-client-secret"
}

module "hub" {
  source  = "cloudcertainty/cloudcertainty-hub/aws"
  version = "0.1.0-rc.18"
  # ...
  identity_provider      = "OIDC"
  oidc_issuer            = "https://login.microsoftonline.com/<tenant-id>/v2.0"
  oidc_client_id         = "<application-client-id>"
  oidc_client_secret_arn = data.aws_secretsmanager_secret.oidc.arn
}
```

Register `https://<cognito_domain output>/oauth2/idpresponse` as the redirect URI in your identity provider. Use `oidc_email_verified_claim = "xms_edov"` for Microsoft Entra ID. CloudFormation reads the secret at deploy time, so the identity running Terraform needs `secretsmanager:GetSecretValue` on it.

### Evaluating without an identity provider

`identity_provider = "CognitoOnly"` creates users in the Hub's Cognito user pool. The bootstrap admin receives an invitation email. See [examples/cognito-only](examples/cognito-only).

### Signing in to products through the Hub

Products installed through the Hub can sign their users in through it: the Hub federates once to your identity provider, and each product stack gets an app client of the Hub's user pool (single sign-on). Choose it when you install or export a product in the Hub. Products you deploy with their own Terraform modules can use it as well, for example `identity_provider = "CloudCertaintyHub"` in the [Secure Browser module](https://registry.terraform.io/modules/cloudcertainty/secure-browser/aws).

### Installing products, or exporting them only

With `deploy_mode = "Full"` (the default) the Hub installs and updates products with its own deployer role (the `deployer_role_arn` output), and only manages product stacks whose names start with `stack_name_prefix` (default `cc-`). `stack_name` must not start with that prefix, so the Hub never manages its own stack. To let the Hub adopt product stacks created outside it with other names, list them in `adoptable_stacks` (IAM then allows the Hub on those names too). With `deploy_mode = "ExportOnly"` no deployer role is created: the Hub only exports each install as Terraform or CloudFormation for you to run.

## Examples

- [IAM Identity Center](examples/iam-identity-center)
- [Cognito only](examples/cognito-only)

## Inputs and outputs

Generated from the module's variables and outputs with [terraform-docs](https://terraform-docs.io)
(`terraform-docs .`); CI fails if this section is out of date.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0, < 7.0 |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bootstrap_admin_email"></a> [bootstrap\_admin\_email](#input\_bootstrap\_admin\_email) | Email of the first hub administrator. | `string` | n/a | yes |
| <a name="input_adoptable_stacks"></a> [adoptable\_stacks](#input\_adoptable\_stacks) | Names of existing product stacks, created outside the hub and not named with stack\_name\_prefix, that the hub may adopt and then update and delete. IAM allows the hub on these names too. Requires hub\_version 0.1.0-rc.15 or later. | `list(string)` | `[]` | no |
| <a name="input_artifact_version_override"></a> [artifact\_version\_override](#input\_artifact\_version\_override) | Leave empty unless Cloud Certainty support asks you to set it. | `string` | `""` | no |
| <a name="input_catalogue_url"></a> [catalogue\_url](#input\_catalogue\_url) | The public product catalogue. Leave null for the default. | `string` | `null` | no |
| <a name="input_cloudformation_role_arn"></a> [cloudformation\_role\_arn](#input\_cloudformation\_role\_arn) | Optional CloudFormation service role to deploy the hub's stack with. | `string` | `null` | no |
| <a name="input_deploy_mode"></a> [deploy\_mode](#input\_deploy\_mode) | Full: the hub installs and updates products with its deployer role. ExportOnly: the hub only exports Terraform and CloudFormation. | `string` | `"Full"` | no |
| <a name="input_hub_version"></a> [hub\_version](#input\_hub\_version) | Cloud Certainty Hub release to deploy (see https://cloudcertainty.com/hub/releases/). Selects the release's CloudFormation template. Each module release defaults to the Hub release it was tested with, so updating usually means raising the module version. | `string` | `"0.1.0-rc.18"` | no |
| <a name="input_identity_center_region"></a> [identity\_center\_region](#input\_identity\_center\_region) | Region to create IAM Identity Center in when there is none. Empty uses the provider's Region. | `string` | `""` | no |
| <a name="input_identity_center_setup"></a> [identity\_center\_setup](#input\_identity\_center\_setup) | CreateIfMissing: use this account's IAM Identity Center or create one; UseExisting: fail when there is none; Disabled: leave it alone. The stack also creates the CloudCertaintyHubAdmins group with a user for bootstrap\_admin\_email. Nothing is ever deleted. | `string` | `"CreateIfMissing"` | no |
| <a name="input_identity_provider"></a> [identity\_provider](#input\_identity\_provider) | How users sign in: IAMIdentityCenter, SAML, OIDC or CognitoOnly. IAMIdentityCenter and SAML need a second apply with saml\_metadata\_url. | `string` | `"IAMIdentityCenter"` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | Optional customer managed KMS key for DynamoDB, CloudWatch Logs and the artifacts bucket. | `string` | `""` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Retention of the hub's CloudWatch log groups, in days. | `number` | `90` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for every resource the stack creates (lowercase letters, digits and hyphens; 2-20 characters, starting with a letter). | `string` | `"cc-hub"` | no |
| <a name="input_oidc_client_id"></a> [oidc\_client\_id](#input\_oidc\_client\_id) | OIDC client ID (identity\_provider = OIDC only). | `string` | `""` | no |
| <a name="input_oidc_client_secret_arn"></a> [oidc\_client\_secret\_arn](#input\_oidc\_client\_secret\_arn) | ARN of the Secrets Manager secret holding the OIDC client secret (identity\_provider = OIDC only). | `string` | `""` | no |
| <a name="input_oidc_email_verified_claim"></a> [oidc\_email\_verified\_claim](#input\_oidc\_email\_verified\_claim) | OIDC claim that says the IdP verified the email. Use xms\_edov for Microsoft Entra ID. | `string` | `"email_verified"` | no |
| <a name="input_oidc_issuer"></a> [oidc\_issuer](#input\_oidc\_issuer) | OIDC issuer URL (identity\_provider = OIDC only). | `string` | `""` | no |
| <a name="input_saml_metadata_url"></a> [saml\_metadata\_url](#input\_saml\_metadata\_url) | SAML metadata URL from IAM Identity Center or your SAML IdP. Leave empty on the first apply. | `string` | `""` | no |
| <a name="input_stack_name"></a> [stack\_name](#input\_stack\_name) | Name of the hub's CloudFormation stack. It must not start with stack\_name\_prefix. | `string` | `"cloudcertainty-hub"` | no |
| <a name="input_stack_name_prefix"></a> [stack\_name\_prefix](#input\_stack\_name\_prefix) | The hub only manages product stacks whose names start with this prefix. | `string` | `"cc-"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the stack and propagated to its resources. Owner, CostCenter and Environment are also passed to the template's tag parameters. | `map(string)` | `{}` | no |
| <a name="input_template_url"></a> [template\_url](#input\_template\_url) | Overrides the S3 URL of the CloudFormation template. Leave null: by default it is https://cloudcertainty-hub-us-east-1.s3.us-east-1.amazonaws.com/<hub\_version>/main.yaml, whatever Region you deploy to. | `string` | `null` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Create, update and delete timeout of the stack. | `string` | `"60m"` | no |
| <a name="input_update_notification_email"></a> [update\_notification\_email](#input\_update\_notification\_email) | Email address for update reminders. Empty uses bootstrap\_admin\_email. AWS sends a confirmation email that must be accepted first. | `string` | `""` | no |
| <a name="input_update_reminders"></a> [update\_reminders](#input\_update\_reminders) | Enabled: email update\_notification\_email when a newer hub release exists, then 1, 3, 7 and 30 days later and every 30 days until the hub is updated. Disabled: no emails. | `string` | `"Enabled"` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_cognito_domain"></a> [cognito\_domain](#output\_cognito\_domain) | Cognito managed login domain. For OIDC, register https://<this domain>/oauth2/idpresponse as the redirect URI. |
| <a name="output_deployer_role_arn"></a> [deployer\_role\_arn](#output\_deployer\_role\_arn) | CloudFormation service role the hub runs product stacks with (Full mode only). |
| <a name="output_hub_version"></a> [hub\_version](#output\_hub\_version) | Cloud Certainty Hub release the stack runs (stack output ProductVersion). |
| <a name="output_identity_center_admin_group_id"></a> [identity\_center\_admin\_group\_id](#output\_identity\_center\_admin\_group\_id) | ID of the CloudCertaintyHubAdmins group; its members are hub administrators. |
| <a name="output_identity_center_instance_arn"></a> [identity\_center\_instance\_arn](#output\_identity\_center\_instance\_arn) | The IAM Identity Center instance the hub uses. |
| <a name="output_identity_center_portal_url"></a> [identity\_center\_portal\_url](#output\_identity\_center\_portal\_url) | AWS access portal URL of IAM Identity Center. |
| <a name="output_identity_center_region"></a> [identity\_center\_region](#output\_identity\_center\_region) | Region of IAM Identity Center: create the hub's SAML application there. |
| <a name="output_identity_center_status"></a> [identity\_center\_status](#output\_identity\_center\_status) | What the stack's IAM Identity Center setup did, or why it could not (the hub's Identity Center page shows the next step). |
| <a name="output_portal_url"></a> [portal\_url](#output\_portal\_url) | URL of the hub. |
| <a name="output_saml_acs_url"></a> [saml\_acs\_url](#output\_saml\_acs\_url) | Assertion Consumer Service (ACS) URL to enter in your IAM Identity Center or SAML application. |
| <a name="output_saml_audience_uri"></a> [saml\_audience\_uri](#output\_saml\_audience\_uri) | SAML audience (entity ID) to enter in your IAM Identity Center or SAML application. |
| <a name="output_stack_id"></a> [stack\_id](#output\_stack\_id) | ID of the hub's CloudFormation stack. |
| <a name="output_stack_outputs"></a> [stack\_outputs](#output\_stack\_outputs) | All outputs of the hub's CloudFormation stack. |
| <a name="output_update_topic_arn"></a> [update\_topic\_arn](#output\_update\_topic\_arn) | SNS topic of the hub's update reminders (null when update\_reminders is Disabled). Subscribe more endpoints, such as AWS Chatbot, to it. |
<!-- END_TF_DOCS -->

## Staying up to date

Each module version `X.Y.Z` deploys Cloud Certainty Hub release `X.Y.Z` by default (module `0.1.0-rc.18` deploys Hub `0.1.0-rc.18`). A release is one CloudFormation template, so nothing changes until you update.

Because the stack is tagged `cloudcertainty:managed-by = terraform`, **the Hub never updates itself**: its About page shows when a newer release exists and tells you which `hub_version` to set, but does not update the stack itself. You hear about new releases in several ways:

- **Email reminders.** With `update_reminders = "Enabled"` (the default) the Hub emails `update_notification_email` (or `bootstrap_admin_email` when it is empty) when a newer Hub release exists, then 1, 3, 7 and 30 days later and every 30 days until the Hub is updated. Each email says to set `hub_version` (or raise the module version). AWS SNS sends a confirmation email first; nothing is delivered until it is confirmed. `update_reminders = "Disabled"` creates no notifier; the Hub still shows the **Update available** badge.
- **Slack, Microsoft Teams and more.** Subscribe AWS Chatbot (Amazon Q Developer in chat applications) or any other SNS subscriber to the `update_topic_arn` output, for example:
  ```hcl
  resource "aws_sns_topic_subscription" "hub_updates_to_queue" {
    topic_arn = module.hub.update_topic_arn
    protocol  = "sqs"
    endpoint  = aws_sqs_queue.platform_notices.arn
  }
  ```
- **GitHub Releases.** Watch this repository (**Watch → Custom → Releases**).
- **Dependabot or Renovate.** Both detect registry modules and open a pull request for each new module version. For Dependabot, add `.github/dependabot.yml` to the repository that holds your Terraform:
  ```yaml
  version: 2
  updates:
    - package-ecosystem: terraform
      directory: "/" # the directory with the module block; add one entry per directory
      schedule:
        interval: weekly
      labels: ["dependencies", "cloudcertainty-hub"]
  ```
  Pin an exact version (`version = "0.1.0-rc.18"`) so the bots can raise it.

## Updating

1. Raise the module version (or merge the Dependabot or Renovate pull request). That also raises `hub_version`, which selects the new release's template. Don't set `hub_version` yourself unless you want to stay on, or move to, a specific release.
2. `terraform init -upgrade` and `terraform plan`: the plan changes the stack's `template_url`.
3. `terraform apply`. CloudFormation updates the stack in place. The Hub can be unavailable for a moment while it updates; the products it installed keep running.

Read the [release notes](https://cloudcertainty.com/hub/releases/) first. If an apply fails, CloudFormation rolls the stack back to where it was on its own.

## Removing

`terraform destroy` deletes the stack. The DynamoDB table holding the Hub's settings and audit log is **retained** by design; delete it manually if you no longer need it. IAM Identity Center, its users and groups, and the product stacks the Hub installed are never deleted with the Hub.

## Security notes

- Nothing sensitive is passed through Terraform. The OIDC client secret is referenced by ARN, and no other input is secret.
- The Hub only reads Cloud Certainty's public catalogue, release manifests and templates; nothing about you or your account is sent anywhere.
- Only Hub administrators (`bootstrap_admin_email`, the members of `CloudCertaintyHubAdmins`, and the emails and groups set in the Hub) can use it.
- With `deploy_mode = "ExportOnly"` the Hub has no role that can create or change stacks.

## License

The code in this repository is licensed under [Apache 2.0](LICENSE). Cloud Certainty Hub is free to use; each Cloud Certainty product is licensed under the Standard Contract for AWS Marketplace when you subscribe to it.

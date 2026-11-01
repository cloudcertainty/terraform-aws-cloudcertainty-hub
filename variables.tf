################################################################################
# General
################################################################################

variable "hub_version" {
  description = "Cloud Certainty Hub release to deploy (see https://cloudcertainty.com/hub/releases/). Selects the release's CloudFormation template. Each module release defaults to the Hub release it was tested with, so updating usually means raising the module version."
  type        = string
  default     = "0.1.0-rc.16"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+(-[A-Za-z0-9.]+)?$", var.hub_version))
    error_message = "hub_version must be a release version such as 1.2.3 or 1.2.3-rc.4."
  }
}

variable "template_url" {
  description = "Overrides the S3 URL of the CloudFormation template. Leave null: by default it is https://cloudcertainty-hub-us-east-1.s3.us-east-1.amazonaws.com/<hub_version>/main.yaml, whatever Region you deploy to."
  type        = string
  default     = null
}

variable "stack_name" {
  description = "Name of the hub's CloudFormation stack. It must not start with stack_name_prefix."
  type        = string
  default     = "cloudcertainty-hub"
}

variable "name_prefix" {
  description = "Prefix for every resource the stack creates (lowercase letters, digits and hyphens; 2-20 characters, starting with a letter)."
  type        = string
  default     = "cc-hub"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,19}$", var.name_prefix))
    error_message = "name_prefix must match ^[a-z][a-z0-9-]{1,19}$."
  }
}

variable "tags" {
  description = "Tags applied to the stack and propagated to its resources. Owner, CostCenter and Environment are also passed to the template's tag parameters."
  type        = map(string)
  default     = {}
}

################################################################################
# Identity (the same options as every Cloud Certainty product)
################################################################################

variable "identity_provider" {
  description = "How users sign in: IAMIdentityCenter, SAML, OIDC or CognitoOnly. IAMIdentityCenter and SAML need a second apply with saml_metadata_url."
  type        = string
  default     = "IAMIdentityCenter"

  validation {
    condition     = contains(["IAMIdentityCenter", "SAML", "OIDC", "CognitoOnly"], var.identity_provider)
    error_message = "identity_provider must be IAMIdentityCenter, SAML, OIDC or CognitoOnly."
  }
}

variable "saml_metadata_url" {
  description = "SAML metadata URL from IAM Identity Center or your SAML IdP. Leave empty on the first apply."
  type        = string
  default     = ""
}

variable "oidc_issuer" {
  description = "OIDC issuer URL (identity_provider = OIDC only)."
  type        = string
  default     = ""
}

variable "oidc_client_id" {
  description = "OIDC client ID (identity_provider = OIDC only)."
  type        = string
  default     = ""
}

variable "oidc_client_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the OIDC client secret (identity_provider = OIDC only)."
  type        = string
  default     = ""
}

variable "oidc_email_verified_claim" {
  description = "OIDC claim that says the IdP verified the email. Use xms_edov for Microsoft Entra ID."
  type        = string
  default     = "email_verified"
}

variable "bootstrap_admin_email" {
  description = "Email of the first hub administrator."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.bootstrap_admin_email))
    error_message = "bootstrap_admin_email must be an email address."
  }
}

variable "identity_center_setup" {
  description = "CreateIfMissing: use this account's IAM Identity Center or create one; UseExisting: fail when there is none; Disabled: leave it alone. The stack also creates the CloudCertaintyHubAdmins group with a user for bootstrap_admin_email. Nothing is ever deleted."
  type        = string
  default     = "CreateIfMissing"

  validation {
    condition     = contains(["CreateIfMissing", "UseExisting", "Disabled"], var.identity_center_setup)
    error_message = "identity_center_setup must be CreateIfMissing, UseExisting or Disabled."
  }
}

variable "identity_center_region" {
  description = "Region to create IAM Identity Center in when there is none. Empty uses the provider's Region."
  type        = string
  default     = ""

  validation {
    condition     = var.identity_center_region == "" || can(regex("^[a-z]{2}(-[a-z]+)+-\\d$", var.identity_center_region))
    error_message = "identity_center_region must be empty or a Region such as eu-west-2."
  }
}

################################################################################
# Installing products
################################################################################

variable "deploy_mode" {
  description = "Full: the hub installs and updates products with its deployer role. ExportOnly: the hub only exports Terraform and CloudFormation."
  type        = string
  default     = "Full"

  validation {
    condition     = contains(["Full", "ExportOnly"], var.deploy_mode)
    error_message = "deploy_mode must be Full or ExportOnly."
  }
}

variable "stack_name_prefix" {
  description = "The hub only manages product stacks whose names start with this prefix."
  type        = string
  default     = "cc-"
}

variable "adoptable_stacks" {
  description = "Names of existing product stacks, created outside the hub and not named with stack_name_prefix, that the hub may adopt and then update and delete. IAM allows the hub on these names too. Requires hub_version 0.1.0-rc.15 or later."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for n in var.adoptable_stacks : can(regex("^[A-Za-z][A-Za-z0-9-]{0,127}$", n))])
    error_message = "adoptable_stacks must be CloudFormation stack names (a letter, then letters, digits and hyphens), with no wildcards."
  }
}

variable "catalogue_url" {
  description = "The public product catalogue. Leave null for the default."
  type        = string
  default     = null
}

################################################################################
# Hub updates
################################################################################

variable "update_reminders" {
  description = "Enabled: email update_notification_email when a newer hub release exists, then 1, 3, 7 and 30 days later and every 30 days until the hub is updated. Disabled: no emails."
  type        = string
  default     = "Enabled"

  validation {
    condition     = contains(["Enabled", "Disabled"], var.update_reminders)
    error_message = "update_reminders must be Enabled or Disabled."
  }
}

variable "update_notification_email" {
  description = "Email address for update reminders. Empty uses bootstrap_admin_email. AWS sends a confirmation email that must be accepted first."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^$|^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.update_notification_email))
    error_message = "update_notification_email must be empty or an email address."
  }
}

################################################################################
# Logging, encryption, deployment
################################################################################

variable "log_retention_days" {
  description = "Retention of the hub's CloudWatch log groups, in days."
  type        = number
  default     = 90
}

variable "kms_key_arn" {
  description = "Optional customer managed KMS key for DynamoDB, CloudWatch Logs and the artifacts bucket."
  type        = string
  default     = ""
}

variable "artifact_version_override" {
  description = "Leave empty unless Cloud Certainty support asks you to set it."
  type        = string
  default     = ""
}

variable "cloudformation_role_arn" {
  description = "Optional CloudFormation service role to deploy the hub's stack with."
  type        = string
  default     = null
}

variable "timeout" {
  description = "Create, update and delete timeout of the stack."
  type        = string
  default     = "60m"
}

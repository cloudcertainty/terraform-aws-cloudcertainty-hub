locals {
  # Release templates live only in the vendor's public bucket in us-east-1. CloudFormation accepts
  # a template URL from any Region, so the same URL deploys the hub wherever the provider points.
  template_url = coalesce(
    var.template_url,
    "https://cloudcertainty-hub-us-east-1.s3.us-east-1.amazonaws.com/${var.hub_version}/main.yaml",
  )

  # Keys mirror the template's parameters. Null values are left out so the template's defaults apply.
  parameters = { for k, v in {
    NamePrefix              = var.name_prefix
    TagOwner                = lookup(var.tags, "Owner", null)
    TagCostCenter           = lookup(var.tags, "CostCenter", null)
    TagEnvironment          = lookup(var.tags, "Environment", null)
    IdentityProvider        = var.identity_provider
    SamlMetadataUrl         = var.saml_metadata_url
    OidcIssuer              = var.oidc_issuer
    OidcClientId            = var.oidc_client_id
    OidcClientSecretArn     = var.oidc_client_secret_arn
    OidcEmailVerifiedClaim  = var.oidc_email_verified_claim
    BootstrapAdminEmail     = var.bootstrap_admin_email
    IdentityCenterSetup     = var.identity_center_setup
    IdentityCenterRegion    = var.identity_center_region
    DeployMode              = var.deploy_mode
    StackNamePrefix         = var.stack_name_prefix
    CatalogueUrl            = var.catalogue_url
    UpdateReminders         = var.update_reminders
    UpdateNotificationEmail = var.update_notification_email
    LogRetentionDays        = tostring(var.log_retention_days)
    KmsKeyArn               = var.kms_key_arn
    ArtifactVersionOverride = var.artifact_version_override
  } : k => v if v != null }

  oidc_complete = var.oidc_issuer != "" && var.oidc_client_id != "" && var.oidc_client_secret_arn != ""
  uses_saml     = contains(["IAMIdentityCenter", "SAML"], var.identity_provider)
}

resource "aws_cloudformation_stack" "this" {
  name         = var.stack_name
  template_url = local.template_url
  parameters   = local.parameters
  iam_role_arn = var.cloudformation_role_arn
  # The hub reads this tag and never updates itself when Terraform manages it.
  tags = merge(var.tags, { "cloudcertainty:managed-by" = "terraform" })

  # The template creates IAM roles, some with fixed names.
  capabilities = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"]

  timeouts {
    create = var.timeout
    update = var.timeout
    delete = var.timeout
  }

  lifecycle {
    # Same checks as the template's Rules, surfaced at plan time.
    precondition {
      condition     = var.identity_provider != "OIDC" || local.oidc_complete
      error_message = "identity_provider = OIDC requires oidc_issuer, oidc_client_id and oidc_client_secret_arn."
    }
    precondition {
      condition     = local.uses_saml || var.saml_metadata_url == ""
      error_message = "saml_metadata_url is only used with identity_provider IAMIdentityCenter or SAML."
    }
    precondition {
      condition     = !startswith(var.stack_name, var.stack_name_prefix)
      error_message = "stack_name must not start with stack_name_prefix, so the hub can never manage its own stack."
    }
  }
}

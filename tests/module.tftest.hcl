# Offline tests (no AWS credentials): terraform test
# Requires Terraform >= 1.7 for mock providers.

mock_provider "aws" {}

variables {
  bootstrap_admin_email = "admin@example.com"
}

run "defaults" {
  command = plan

  assert {
    condition     = aws_cloudformation_stack.this.name == "cloudcertainty-hub"
    error_message = "unexpected default stack name: ${aws_cloudformation_stack.this.name}"
  }
  assert {
    condition     = aws_cloudformation_stack.this.template_url == "https://cloudcertainty-hub-us-east-1.s3.us-east-1.amazonaws.com/0.1.0-rc.18/main.yaml"
    error_message = "template URL must be the us-east-1 release bucket with the default hub_version: ${aws_cloudformation_stack.this.template_url}"
  }
  assert {
    condition     = aws_cloudformation_stack.this.tags["cloudcertainty:managed-by"] == "terraform"
    error_message = "the cloudcertainty:managed-by = terraform tag must be set (the hub never updates a Terraform-managed stack)"
  }
  assert {
    condition     = aws_cloudformation_stack.this.parameters["NamePrefix"] == "cc-hub"
    error_message = "unexpected default NamePrefix"
  }
  assert {
    condition     = aws_cloudformation_stack.this.parameters["BootstrapAdminEmail"] == "admin@example.com"
    error_message = "bootstrap_admin_email must be passed as BootstrapAdminEmail"
  }
  assert {
    condition     = aws_cloudformation_stack.this.parameters["IdentityProvider"] == "IAMIdentityCenter"
    error_message = "unexpected default IdentityProvider"
  }
  assert {
    condition     = aws_cloudformation_stack.this.parameters["UpdateReminders"] == "Enabled"
    error_message = "update reminders should be enabled by default"
  }
  assert {
    condition     = aws_cloudformation_stack.this.parameters["UpdateNotificationEmail"] == ""
    error_message = "no separate notification email by default (the reminders go to the bootstrap admin)"
  }
  assert {
    condition     = aws_cloudformation_stack.this.parameters["LogRetentionDays"] == "90"
    error_message = "log_retention_days must be passed as a string"
  }
  assert {
    condition     = contains(aws_cloudformation_stack.this.capabilities, "CAPABILITY_NAMED_IAM") && contains(aws_cloudformation_stack.this.capabilities, "CAPABILITY_IAM")
    error_message = "CAPABILITY_IAM and CAPABILITY_NAMED_IAM are required"
  }
}

run "null_inputs_left_out" {
  command = plan

  assert {
    condition     = !contains(keys(aws_cloudformation_stack.this.parameters), "CatalogueUrl")
    error_message = "catalogue_url = null must be left out so the template default applies"
  }
  assert {
    condition = (
      !contains(keys(aws_cloudformation_stack.this.parameters), "TagOwner") &&
      !contains(keys(aws_cloudformation_stack.this.parameters), "TagCostCenter") &&
      !contains(keys(aws_cloudformation_stack.this.parameters), "TagEnvironment")
    )
    error_message = "missing tag keys must be left out so the template defaults apply"
  }
  assert {
    condition     = !contains(keys(aws_cloudformation_stack.this.parameters), "AdoptableStacks")
    error_message = "no adoptable_stacks must be left out, so older hub templates (without the parameter) still deploy"
  }
  assert {
    condition     = !contains(values(aws_cloudformation_stack.this.parameters), "0.1.0-rc.18")
    error_message = "hub_version selects the template and must not be passed as a stack parameter"
  }
}

run "hub_version_selects_template" {
  command = plan

  variables {
    hub_version = "0.1.0-rc.10"
  }

  assert {
    condition     = aws_cloudformation_stack.this.template_url == "https://cloudcertainty-hub-us-east-1.s3.us-east-1.amazonaws.com/0.1.0-rc.10/main.yaml"
    error_message = "unexpected template URL: ${aws_cloudformation_stack.this.template_url}"
  }
}

run "explicit_template_url_wins" {
  command = plan

  variables {
    template_url = "https://example-bucket.s3.eu-west-2.amazonaws.com/custom/main.yaml"
  }

  assert {
    condition     = aws_cloudformation_stack.this.template_url == "https://example-bucket.s3.eu-west-2.amazonaws.com/custom/main.yaml"
    error_message = "template_url override not used"
  }
}

run "invalid_hub_version_rejected" {
  command = plan

  variables {
    hub_version = "latest"
  }

  expect_failures = [var.hub_version]
}

run "managed_by_tag_cannot_be_overridden" {
  command = plan

  variables {
    tags = {
      Owner                       = "platform-team"
      CostCenter                  = "42"
      Environment                 = "prod"
      "cloudcertainty:managed-by" = "hub"
    }
  }

  assert {
    condition     = aws_cloudformation_stack.this.tags["cloudcertainty:managed-by"] == "terraform"
    error_message = "the managed-by tag must stay terraform whatever tags are passed"
  }
  assert {
    condition     = aws_cloudformation_stack.this.tags["Owner"] == "platform-team"
    error_message = "the caller's tags must be applied to the stack"
  }
  assert {
    condition = (
      aws_cloudformation_stack.this.parameters["TagOwner"] == "platform-team" &&
      aws_cloudformation_stack.this.parameters["TagCostCenter"] == "42" &&
      aws_cloudformation_stack.this.parameters["TagEnvironment"] == "prod"
    )
    error_message = "Owner, CostCenter and Environment must feed the template's tag parameters"
  }
}

run "update_reminder_settings_mapped" {
  command = plan

  variables {
    update_reminders          = "Disabled"
    update_notification_email = "platform-team@example.com"
  }

  assert {
    condition     = aws_cloudformation_stack.this.parameters["UpdateReminders"] == "Disabled"
    error_message = "update_reminders must be passed as UpdateReminders"
  }
  assert {
    condition     = aws_cloudformation_stack.this.parameters["UpdateNotificationEmail"] == "platform-team@example.com"
    error_message = "update_notification_email must be passed as UpdateNotificationEmail"
  }
}

run "invalid_update_reminders_rejected" {
  command = plan

  variables {
    update_reminders = "Weekly"
  }

  expect_failures = [var.update_reminders]
}

run "invalid_notification_email_rejected" {
  command = plan

  variables {
    update_notification_email = "not-an-email"
  }

  expect_failures = [var.update_notification_email]
}

run "invalid_bootstrap_admin_email_rejected" {
  command = plan

  variables {
    bootstrap_admin_email = "admin"
  }

  expect_failures = [var.bootstrap_admin_email]
}

run "oidc_requires_all_settings" {
  command = plan

  variables {
    identity_provider = "OIDC"
    oidc_issuer       = "https://idp.example.com"
    oidc_client_id    = "client"
  }

  expect_failures = [aws_cloudformation_stack.this]
}

run "oidc_settings_mapped" {
  command = plan

  variables {
    identity_provider         = "OIDC"
    oidc_issuer               = "https://login.microsoftonline.com/00000000-0000-0000-0000-000000000000/v2.0"
    oidc_client_id            = "client"
    oidc_client_secret_arn    = "arn:aws:secretsmanager:eu-west-2:123456789012:secret:hub/oidc-AbCdEf"
    oidc_email_verified_claim = "xms_edov"
  }

  assert {
    condition = (
      aws_cloudformation_stack.this.parameters["IdentityProvider"] == "OIDC" &&
      aws_cloudformation_stack.this.parameters["OidcIssuer"] == "https://login.microsoftonline.com/00000000-0000-0000-0000-000000000000/v2.0" &&
      aws_cloudformation_stack.this.parameters["OidcClientId"] == "client" &&
      aws_cloudformation_stack.this.parameters["OidcClientSecretArn"] == "arn:aws:secretsmanager:eu-west-2:123456789012:secret:hub/oidc-AbCdEf" &&
      aws_cloudformation_stack.this.parameters["OidcEmailVerifiedClaim"] == "xms_edov"
    )
    error_message = "the OIDC inputs must be passed to the template"
  }
}

run "saml_url_rejected_for_cognito_only" {
  command = plan

  variables {
    identity_provider = "CognitoOnly"
    saml_metadata_url = "https://example.com/metadata.xml"
  }

  expect_failures = [aws_cloudformation_stack.this]
}

run "saml_url_rejected_for_oidc" {
  command = plan

  variables {
    identity_provider      = "OIDC"
    oidc_issuer            = "https://idp.example.com"
    oidc_client_id         = "client"
    oidc_client_secret_arn = "arn:aws:secretsmanager:eu-west-2:123456789012:secret:hub/oidc-AbCdEf"
    saml_metadata_url      = "https://example.com/metadata.xml"
  }

  expect_failures = [aws_cloudformation_stack.this]
}

run "saml_url_accepted_for_identity_center" {
  command = plan

  variables {
    saml_metadata_url = "https://portal.sso.eu-west-2.amazonaws.com/saml/metadata/ABCDEF"
  }

  assert {
    condition     = aws_cloudformation_stack.this.parameters["SamlMetadataUrl"] == "https://portal.sso.eu-west-2.amazonaws.com/saml/metadata/ABCDEF"
    error_message = "saml_metadata_url must be passed as SamlMetadataUrl"
  }
}

run "unknown_identity_provider_rejected" {
  command = plan

  variables {
    identity_provider = "CloudCertaintyHub"
  }

  expect_failures = [var.identity_provider]
}

run "stack_name_must_not_start_with_managed_prefix" {
  command = plan

  variables {
    stack_name = "cc-hub"
  }

  expect_failures = [aws_cloudformation_stack.this]
}

run "adoptable_stacks_mapped" {
  command = plan

  variables {
    adoptable_stacks = ["sqlark", "bucketdeck-prod"]
  }

  assert {
    condition     = aws_cloudformation_stack.this.parameters["AdoptableStacks"] == "sqlark,bucketdeck-prod"
    error_message = "adoptable_stacks must be passed as a comma-separated AdoptableStacks"
  }
}

run "adoptable_stacks_wildcard_rejected" {
  command = plan

  variables {
    adoptable_stacks = ["sqlark-*"]
  }

  expect_failures = [var.adoptable_stacks]
}

run "adoptable_stacks_must_not_list_the_hub" {
  command = plan

  variables {
    adoptable_stacks = ["cloudcertainty-hub"]
  }

  expect_failures = [aws_cloudformation_stack.this]
}

run "custom_stack_name" {
  command = plan

  variables {
    stack_name = "acme-hub"
  }

  assert {
    condition     = aws_cloudformation_stack.this.name == "acme-hub"
    error_message = "stack_name must be used as given"
  }
}

run "install_settings_mapped" {
  command = plan

  variables {
    deploy_mode            = "ExportOnly"
    identity_center_setup  = "UseExisting"
    identity_center_region = "eu-west-1"
    stack_name_prefix      = "acme-"
    catalogue_url          = "https://example.com/catalog.json"
  }

  assert {
    condition = (
      aws_cloudformation_stack.this.parameters["DeployMode"] == "ExportOnly" &&
      aws_cloudformation_stack.this.parameters["IdentityCenterSetup"] == "UseExisting" &&
      aws_cloudformation_stack.this.parameters["IdentityCenterRegion"] == "eu-west-1" &&
      aws_cloudformation_stack.this.parameters["StackNamePrefix"] == "acme-" &&
      aws_cloudformation_stack.this.parameters["CatalogueUrl"] == "https://example.com/catalog.json"
    )
    error_message = "install settings must be passed to the template"
  }
}

run "invalid_deploy_mode_rejected" {
  command = plan

  variables {
    deploy_mode = "ReadOnly"
  }

  expect_failures = [var.deploy_mode]
}

run "invalid_name_prefix_rejected" {
  command = plan

  variables {
    name_prefix = "Bad_Prefix"
  }

  expect_failures = [var.name_prefix]
}

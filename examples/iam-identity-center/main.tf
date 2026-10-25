# Sign-in through AWS IAM Identity Center, in two applies:
#
# 1. terraform apply with saml_metadata_url left empty. The stack finds or creates
#    IAM Identity Center in the account and adds the bootstrap admin to the
#    CloudCertaintyHubAdmins group.
# 2. In IAM Identity Center (in the identity_center_region output), add a SAML 2.0
#    application with the portal_url, saml_acs_url and saml_audience_uri outputs.
# 3. terraform apply -var saml_metadata_url=<the application's metadata URL>.

provider "aws" {
  region = "eu-west-2"
}

variable "saml_metadata_url" {
  description = "SAML metadata URL of the hub's IAM Identity Center application. Empty on the first apply."
  type        = string
  default     = ""
}

module "hub" {
  source = "../.."

  identity_provider         = "IAMIdentityCenter"
  saml_metadata_url         = var.saml_metadata_url
  bootstrap_admin_email     = "admin@example.com"
  update_notification_email = "platform-team@example.com"
}

output "portal_url" {
  value = module.hub.portal_url
}

output "saml_acs_url" {
  value = module.hub.saml_acs_url
}

output "saml_audience_uri" {
  value = module.hub.saml_audience_uri
}

output "identity_center_region" {
  value = module.hub.identity_center_region
}

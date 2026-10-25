# Quick evaluation without an external identity provider. Users are created in
# the hub's Cognito user pool; the bootstrap admin receives an invitation email.

provider "aws" {
  region = "eu-west-2"
}

module "hub" {
  source = "../.."

  identity_provider     = "CognitoOnly"
  bootstrap_admin_email = "admin@example.com"

  tags = {
    Owner       = "platform-team"
    Environment = "prod"
  }
}

output "portal_url" {
  value = module.hub.portal_url
}

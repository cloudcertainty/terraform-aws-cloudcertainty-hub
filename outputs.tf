output "portal_url" {
  description = "URL of the hub."
  value       = try(aws_cloudformation_stack.this.outputs["PortalUrl"], null)
}

output "hub_version" {
  description = "Cloud Certainty Hub release the stack runs (stack output ProductVersion)."
  value       = try(aws_cloudformation_stack.this.outputs["ProductVersion"], null)
}

output "update_topic_arn" {
  description = "SNS topic of the hub's update reminders (null when update_reminders is Disabled). Subscribe more endpoints, such as AWS Chatbot, to it."
  value       = try(aws_cloudformation_stack.this.outputs["UpdateTopicArn"], null)
}

output "saml_acs_url" {
  description = "Assertion Consumer Service (ACS) URL to enter in your IAM Identity Center or SAML application."
  value       = try(aws_cloudformation_stack.this.outputs["SamlAcsUrl"], null)
}

output "saml_audience_uri" {
  description = "SAML audience (entity ID) to enter in your IAM Identity Center or SAML application."
  value       = try(aws_cloudformation_stack.this.outputs["SamlAudienceUri"], null)
}

output "cognito_domain" {
  description = "Cognito managed login domain. For OIDC, register https://<this domain>/oauth2/idpresponse as the redirect URI."
  value       = try(aws_cloudformation_stack.this.outputs["CognitoDomain"], null)
}

output "deployer_role_arn" {
  description = "CloudFormation service role the hub runs product stacks with (Full mode only)."
  value       = try(aws_cloudformation_stack.this.outputs["DeployerRoleArn"], null)
}

output "identity_center_instance_arn" {
  description = "The IAM Identity Center instance the hub uses."
  value       = try(aws_cloudformation_stack.this.outputs["IdentityCenterInstanceArn"], null)
}

output "identity_center_region" {
  description = "Region of IAM Identity Center: create the hub's SAML application there."
  value       = try(aws_cloudformation_stack.this.outputs["IdentityCenterRegion"], null)
}

output "identity_center_portal_url" {
  description = "AWS access portal URL of IAM Identity Center."
  value       = try(aws_cloudformation_stack.this.outputs["IdentityCenterPortalUrl"], null)
}

output "identity_center_admin_group_id" {
  description = "ID of the CloudCertaintyHubAdmins group; its members are hub administrators."
  value       = try(aws_cloudformation_stack.this.outputs["IdentityCenterAdminGroupId"], null)
}

output "stack_id" {
  description = "ID of the hub's CloudFormation stack."
  value       = aws_cloudformation_stack.this.id
}

output "identity_center_status" {
  description = "What the stack's IAM Identity Center setup did, or why it could not (the hub's Identity Center page shows the next step)."
  value       = try(aws_cloudformation_stack.this.outputs["IdentityCenterStatus"], null)
}

output "stack_outputs" {
  description = "All outputs of the hub's CloudFormation stack."
  value       = aws_cloudformation_stack.this.outputs
}

variable "parameters" {
  type = map(any)
  default = {
    AdminEmail               = "example@admin.com"
    CertificateArnELB        = "arn:aws:acm:us-east-1:EXAMPLE"
    ApiGatewayVPCEndpointId  = "vpce-EXAMPLE"
    DBUser                   = "root"
    PasswordAuth             = "Disabled"
    SingleSignOnClientId     = "EXAMPLE"
    SingleSignOnClientSecret = "EXAMPLE"
    SingleSignOnBaseUrl      = "https://yourcompany.okta.com/oauth2/default"
    QuiltWebHost             = "quilt.yourcompany.com"
    SecurityGroup            = "sg-EXAMPLE"
    VPC                      = "vpc-EXAMPLE"
  }
}

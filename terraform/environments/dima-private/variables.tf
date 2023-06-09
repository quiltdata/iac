variable "parameters" {
  type = map(any)
  default = {
    AdminEmail           = "dima@quiltdata.io"
    CertificateArnELB    = "arn:aws:acm:us-east-2:060758809828:certificate/1b8ee00c-8858-4ff0-8788-d36c64fb1f99"
    CloudTrailBucket     = "dima-fake-cloudtrail"
    PasswordAuth         = "Enabled"
    QuiltWebHost         = "dima-tf-private.quiltdata.com"
    OneLoginBaseUrl      = ""
    OneLoginClientSecret = ""
    AzureClientSecret    = ""
    OktaBaseUrl          = ""
    OktaClientSecret     = ""
    SingleSignOnDomains  = ""
    OktaClientId         = ""
    GoogleClientId       = ""
    GoogleClientSecret   = ""
    OneLoginClientId     = ""
    AzureBaseUrl         = ""
    AzureClientId        = ""
  }
}

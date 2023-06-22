provider "aws" {
  region              = "..."
  allowed_account_ids = ["..."]
}

module "quilt" {
  source = "github.com/quiltdata/iac//terraform/modules/quilt?ref=aecc1e35047820ac8790bfd60d24df67cb01576a"

  name          = "quilt"
  internal      = true
  template_file = ".../quilt.yaml"

  db_multi_az = false

  db_snapshot_identifier = "..."  # Safe to delete after the initial deployment

  search_instance_count            = 1
  search_instance_type             = "t3.small.elasticsearch"
  search_dedicated_master_enabled  = false
  search_zone_awareness_enabled    = false
  search_volume_size               = 35

  parameters = {
    AdminEmail           = "..."
    CertificateArnELB    = "arn:aws:..."
    QuiltWebHost         = "..."
    PasswordAuth         = "Enabled"
    GoogleAuth           = "Disabled"
    GoogleClientId       = ""
    GoogleClientSecret   = ""
    SingleSignOnDomains  = ""
    OktaAuth             = "Disabled"
    OktaBaseUrl          = ""
    OktaClientId         = ""
    OktaClientSecret     = ""
    OneLoginAuth         = "Disabled"
    OneLoginBaseUrl      = ""
    OneLoginClientId     = ""
    OneLoginClientSecret = ""
    AzureAuth            = "Disabled"
    AzureBaseUrl         = ""
    AzureClientId        = ""
    AzureClientSecret    = ""
  }
}

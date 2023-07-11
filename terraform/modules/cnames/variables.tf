variable "lb_dns_name" {
  description = "DNS name for the Quilt application load balancer"
  type        = string
  nullable = false
}

variable "quilt_web_host" {
  description = "QuiltWebHost parameter for stack"
  type = string
  nullable = false
}

variable "ttl" {
  description = "Record time to live"
  default = 60
  type = number
  nullable = false
}

variable "zone_id" {
  description = "Hosted zone id"
  default = "Z08925852XFGELN33FZFQ"
  type        = string
  nullable = false
}
variable "lb_dns_name" {
  description = "DNS name for the Quilt application load balancer"
  type        = string
}

variable "quilt_web_host" {
  description = "QuiltWebHost parameter for stack"
  type = string
}

variable "ttl" {
  description = "Record time to live"
  default = 60
  type = number
}

variable "zone_id" {
  description = "Hosted zone id"
  deafult = "Z08925852XFGELN33FZFQ"
  type        = string
}
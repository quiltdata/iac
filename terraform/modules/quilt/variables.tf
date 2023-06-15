variable "name" {
  type     = string
  nullable = false
}

variable "cidr" {
  type     = string
  nullable = false
  default  = "10.0.0.0/16"
}

variable "internal" {
  type     = bool
  nullable = false
}

variable "db_snapshot_identifier" {
  type     = string
  nullable = true
  default  = null
}

variable "db_instance_class" {
  type     = string
  nullable = false
  default  = "db.t3.small"
}

variable "template_url" {
  type     = string
  nullable = false
}

variable "parameters" {
  type        = map(any)
  nullable    = false
  description = "CFT parameters"
}

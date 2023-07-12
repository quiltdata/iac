variable "identifier" {
  type     = string
  nullable = false
}

variable "vpc_id" {
  type     = string
  nullable = false
}

variable "subnet_ids" {
  type     = list(string)
  nullable = false
}

variable "snapshot_identifier" {
  type     = string
  nullable = true
}

variable "instance_class" {
  type     = string
  nullable = false
}

variable "multi_az" {
  type     = bool
  nullable = false
}

variable "backup_retention_period" {
  type = number
  default = 35
}

variable "name" {
  type     = string
  nullable = false
}

variable "cidr" {
  type     = string
  nullable = false
}

variable "internal" {
  type     = bool
  nullable = false
}

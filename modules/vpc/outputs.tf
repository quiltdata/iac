output "vpc" {
  description = "VPC"
  value       = module.vpc
}

output "api_endpoint" {
  description = "API Gateway VPC endpoint (if internal=true)"
  value       = var.internal ? module.vpc_endpoints.endpoints["api"] : null
}

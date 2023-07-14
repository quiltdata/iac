output "search" {
  description = "Search"
  value       = aws_elasticsearch_domain.search
}

output "search_accessor_security_group" {
  description = "Search Accessor Security Group"
  value       = module.search_accessor_security_group
}

output "web_url" {
  description = "Open this in a browser. This is the lab's visible result."
  value       = "http://${aws_instance.web.public_ip}"
}

output "instance_id" {
  description = "ID of the web server instance."
  value       = aws_instance.web.id
}

output "vpc_id" {
  description = "ID of the purpose-built VPC."
  value       = aws_vpc.main.id
}

output "subnet_cidr" {
  description = "CIDR that cidrsubnet() computed for the public subnet."
  value       = aws_subnet.public.cidr_block
}

output "managed_resource_count" {
  description = "How many AWS objects this one mini-app is made of. Computed, not typed -- a hardcoded count here was wrong by one on the first run."
  value       = length(concat(
    [aws_vpc.main.id, aws_internet_gateway.main.id, aws_subnet.public.id,
     aws_route_table.public.id, aws_route_table_association.public.id,
     aws_security_group.web.id, aws_vpc_security_group_ingress_rule.http.id,
     aws_vpc_security_group_egress_rule.all.id, aws_instance.web.id]
  ))
}

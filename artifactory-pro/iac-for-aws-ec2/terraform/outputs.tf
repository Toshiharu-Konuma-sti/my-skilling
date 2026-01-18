output "db_ip" {
  value = aws_instance.db_node.public_ip
  description = "DB Node Public IP"
}

output "nfs_ip" {
  value = aws_instance.nfs_node.public_ip
  description = "NFS Node Public IP"
}

output "artifactory_ip" {
  value = aws_instance.artifactory_node[*].public_ip
  description = "Artifactory Node Public IP"
}

output "haproxy_ip" {
  value = aws_instance.haproxy_node.public_ip
  description = "HAProxy Load Balancer Public IP"
}

output "xray_ip" {
  value = aws_instance.xray_node.public_ip
  description = "Xray Node Public IP"
}

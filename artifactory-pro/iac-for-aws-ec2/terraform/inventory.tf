# インベントリファイルを自動生成するリソース定義
resource "local_file" "ansible_inventory" {
  # 出力先のパス (terraformディレクトリから見て、一つ上のansibleディレクトリへ)
  filename = "../ansible/inventory.ini"
  file_permission = "0644"

  # ファイルの中身 (ヒアドキュメントでテンプレートを作成)
  content = <<EOT
[db]
${aws_instance.db_node.public_ip}

[nfs]
${aws_instance.nfs_node.public_ip}

[artifactory]
%{ for ip in aws_instance.artifactory_node.*.public_ip ~}
${ip}
%{ endfor ~}

[haproxy]
${aws_instance.haproxy_node.public_ip}

[xray]
${aws_instance.xray_node.public_ip}


[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/${var.ec2_ssh_key_name}.pem
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOT

}

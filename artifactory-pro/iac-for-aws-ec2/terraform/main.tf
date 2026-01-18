#--------------------------------------------------------------------
# region
#--------------------------------------------------------------------

provider "aws" {
  region = "ap-northeast-1" # 東京リージョン
}

#--------------------------------------------------------------------
# network
#--------------------------------------------------------------------

# VPC (ネットワークの箱)
resource "aws_vpc" "jfrog_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "${var.project_prefix}-jfrog-vpc" }
}

# インターネットゲートウェイ (外に出るためのドア)
resource "aws_internet_gateway" "jfrog_igw" {
  vpc_id = aws_vpc.jfrog_vpc.id
  tags = { Name = "${var.project_prefix}-jfrog-igw" }
}

# サブネット (サーバーを置く場所)
resource "aws_subnet" "jfrog_subnet" {
  vpc_id                  = aws_vpc.jfrog_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true # 自動でパブリックIPを付与
  tags = { Name = "${var.project_prefix}-jfrog-subnet" }
}

# ルートテーブル (道案内)
resource "aws_route_table" "jfrog_rt" {
  vpc_id = aws_vpc.jfrog_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jfrog_igw.id
  }
  tags = { Name = "${var.project_prefix}-jfrog-rt" }
}

# ルートテーブルをサブネットに紐付け
resource "aws_route_table_association" "jfrog_rta" {
  subnet_id      = aws_subnet.jfrog_subnet.id
  route_table_id = aws_route_table.jfrog_rt.id
}

#--------------------------------------------------------------------
# security group
#--------------------------------------------------------------------

# 共通のセキュリティグループ（内部通信フルオープン、外部からはSSHとUIのみ）
resource "aws_security_group" "jfrog_sg" {
  name   = "${var.project_prefix}-jfrog-sg"
  vpc_id = aws_vpc.jfrog_vpc.id

  # SSH
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }
  # Load Balancer (ブラウザからは http://<LB_IP> でアクセスするため80を開ける)
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }
  # HAProxy Stats Page (管理画面用)
  ingress {
    from_port = 8404
    to_port   = 8404
    protocol  = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }
  # Artifactory UI (直接アクセス用 - デバッグ向け)
  ingress {
    from_port = 8081
    to_port   = 8082
    protocol  = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }
  # 内部通信 (簡易化のため、このSG内からの通信はすべて許可)
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }
  # アウトバウンド (全許可)
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#--------------------------------------------------------------------
# ec2 instance
#--------------------------------------------------------------------

# 最新のUbuntu 24.04 (Noble) のAMI IDを取得するデータソース
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical.com's aws account id

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# DB Node
resource "aws_instance" "db_node" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small"
  key_name      = "${var.ec2_ssh_key_name}" 
  
  subnet_id              = aws_subnet.jfrog_subnet.id
  vpc_security_group_ids = [aws_security_group.jfrog_sg.id]
  
  tags = { Name = "${var.project_prefix}-jfrog-vm-db" }
}

# NFS Node (Storage Server)
resource "aws_instance" "nfs_node" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small"
  key_name      = "${var.ec2_ssh_key_name}" 

  subnet_id              = aws_subnet.jfrog_subnet.id
  vpc_security_group_ids = [aws_security_group.jfrog_sg.id]

  tags = { Name = "${var.project_prefix}-jfrog-vm-nfs" }

  # 本来はEBSボリューム推奨(学習用で少し大きめのルートボリューム)
  root_block_device {
    volume_size = 50 
    volume_type = "gp3"
  }
}

# Artifactory Node
resource "aws_instance" "artifactory_node" {
  count         = var.artifactory_node_count
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  key_name      = "${var.ec2_ssh_key_name}" 

  subnet_id              = aws_subnet.jfrog_subnet.id
  vpc_security_group_ids = [aws_security_group.jfrog_sg.id]

  tags = { Name = "${var.project_prefix}-jfrog-vm-artifactory-${count.index + 1}" }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
}

# Load Balancer Node (HAProxy)
resource "aws_instance" "haproxy_node" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = "${var.ec2_ssh_key_name}" 

  subnet_id              = aws_subnet.jfrog_subnet.id
  vpc_security_group_ids = [aws_security_group.jfrog_sg.id]

  tags = { Name = "${var.project_prefix}-jfrog-vm-haproxy" }
}

# Xray Node
resource "aws_instance" "xray_node" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  key_name      = "${var.ec2_ssh_key_name}" 

  subnet_id              = aws_subnet.jfrog_subnet.id
  vpc_security_group_ids = [aws_security_group.jfrog_sg.id]

  tags = { Name = "${var.project_prefix}-jfrog-vm-xray" }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
}

#Put your main terraform here....
data "aws_caller_identity" "current" {}

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Project  = var.PROJECT
    Name = "vpc-${var.PROJECT}"
  }
}

resource "aws_subnet" "subnetA" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "${var.REGION}a"
  tags = {
    Project  = var.PROJECT
    Name = "sn-${var.PROJECT}a"
  }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Project  = var.PROJECT
    Name = "igw-${var.PROJECT}"
  }
}
resource "aws_route_table" "my_vpc_public" {
  vpc_id = aws_vpc.my_vpc.id
  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Project  = var.PROJECT
    Name = "rt-${var.PROJECT}"
  }
}
resource "aws_route_table_association" "my_vpc_A_public" {
    subnet_id = aws_subnet.subnetA.id
    route_table_id = aws_route_table.my_vpc_public.id
}
resource "aws_security_group" "allow_ssh" {
  name = "allow_ssh"
  vpc_id = aws_vpc.my_vpc.id
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 8200
    to_port = 8200
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 0
    to_port = 0
    protocol = -1
    self = true
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Project  = var.PROJECT
    Name = "sg-${var.PROJECT}-http"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}
resource "aws_key_pair" "kp" {
  key_name   = "regularserver-kp"
  public_key = file("./ec2.pub")
  tags = {
    Project = var.PROJECT
  }
}
resource "aws_instance" "regularserver" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.kp.key_name
  associate_public_ip_address = true
  vpc_security_group_ids = [ aws_security_group.allow_ssh.id ]
  subnet_id = aws_subnet.subnetA.id
  depends_on = [ aws_instance.vaultserver ]
  user_data = data.template_file.installVaultHelper.rendered
  tags = {
    Name = var.EC2_NAME
    Project = var.PROJECT
  }

}
data "template_file" "installVaultHelper" {
  template = "${file("installVaultHelper.tpl")}"
  vars = {
    vault_address = "${aws_instance.vaultserver.public_ip}"
  }
}

resource "aws_instance" "vaultserver" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.kp.key_name
  associate_public_ip_address = true
  vpc_security_group_ids = [ aws_security_group.allow_ssh.id ]
  subnet_id = aws_subnet.subnetA.id
  tags = {
    Name = var.VAULT_NAME
    Project = var.PROJECT
  }
  user_data = "${file("installVault.sh")}"
}

resource "aws_secretsmanager_secret" "instancekey" {
    name = aws_instance.regularserver.id
    depends_on = [
      aws_instance.regularserver
    ]
}
resource "aws_secretsmanager_secret" "vaultkey" {
    name = aws_instance.vaultserver.id
    depends_on = [
      aws_instance.vaultserver
    ]
}
resource "aws_secretsmanager_secret_version" "instancekey" {
  secret_id     = aws_secretsmanager_secret.instancekey.id
  secret_string = file("./ec2")
}
resource "aws_secretsmanager_secret_version" "vaultkey" {
  secret_id     = aws_secretsmanager_secret.vaultkey.id
  secret_string = file("./ec2")
}
resource "aws_secretsmanager_secret_policy" "instancekeypolicy" {
  secret_arn = aws_secretsmanager_secret.instancekey.arn
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EnableAllPermissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${data.aws_caller_identity.current.arn}"
      },
      "Action": "secretsmanager:GetSecretValue",
      "Resource": "*"
    }
  ]
}
POLICY
}
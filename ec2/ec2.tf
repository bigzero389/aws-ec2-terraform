# AWS용 프로바이더 구성
provider "aws" {
  profile = "default"
  #region = "ap-northeast-2"
  region = "ap-northeast-1"
}

data "aws_region" "current" {}

locals {
  Region = "${data.aws_region.current.name}"
  CidrPrefix = "10.75"
  Owner = "dy"
  Creator = "dyheo"
  Group = "cloudteam"

  PemFile = "dy-tokyo-key"

  ## EC2 를 만들기 위한 로컬변수 선언
  ## aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2 --region ap-northeast-1
  ami = "ami-0224c3ca00a6ee32f"
  instance_type = "t2.micro"
}

## TAG NAME 으로 vpc id 를 가져온다.
data "aws_vpc" "this" {
  filter {
    name = "tag:Name"
    values = ["${local.Owner}-vpc"]
  }
}

## TAG NAME 으로 security group 을 가져온다.
data "aws_security_group" "sg-core" {
  vpc_id = "${data.aws_vpc.this.id}"
  filter {
    name = "tag:Name"
    values = ["${local.Owner}-sg-core"]
  }
}

/*
resource "aws_security_group" "sg-ec2" {
  name = "${local.Owner}-sg-ec2"
  description = "ec2 server 80 service test"
  vpc_id = "${data.aws_vpc.this.id}"

  #ingress {
  #  from_port       = 3000
  #  protocol        = "tcp"
  #  to_port         = 3000
  #  cidr_blocks = [data.aws_vpc.this.cidr_block,"125.177.68.23/32","211.206.114.80/32"]
  #}

  ingress {
    from_port       = 8080 
    protocol        = "tcp"
    to_port         = 8080
    cidr_blocks = [data.aws_vpc.this.cidr_block,"125.177.68.23/32","211.206.114.80/32"]
  }

  ## mysql port 
  #ingress {
  #  from_port       = 3306
  #  protocol        = "tcp"
  #  to_port         = 3306
  #  cidr_blocks = [data.aws_vpc.this.cidr_block,"125.177.68.23/32","211.206.114.80/32"]
  #}

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.Owner}-sg-ec2"
    Creator = "${local.Creator}"
    Group = "${local.Group}"
  }
}
*/

## TAG NAME 으로 subnet 을 가져온다.
data "aws_subnet_ids" "public" {
  vpc_id = "${data.aws_vpc.this.id}"
  filter {
    name = "tag:Name"
    values = ["${local.Owner}-sb-public-*"]
  }
}

data "aws_subnet" "public" {
  for_each = data.aws_subnet_ids.public.ids
  id = each.value
}

# AWS EC2
resource "aws_instance" "dyheo-ec2" {
  ## public subnet 개수만큼 ec2 를 만든다.
  ami = "${local.ami}"
  associate_public_ip_address = true
  instance_type = "${local.instance_type}"
  key_name = "${local.PemFile}"
#  vpc_security_group_ids = [
#    "${data.aws_security_group.sg-core.id}",
#    "${aws_security_group.sg-ec2.id}"
#  ]
  vpc_security_group_ids = [
    "${data.aws_security_group.sg-core.id}"
  ]


  count = length(data.aws_subnet_ids.public.ids)
  #subnet_id = "${data.aws_subnet.public.id}"
  subnet_id = element(tolist(data.aws_subnet_ids.public.ids), count.index)

  tags = {
    Name = "${local.Owner}-ec2-${count.index + 1}",
    Creator = "${local.Creator}"
    Group = "${local.Group}"
  }

# EC2 preconfig
#  provisioner "remote-exec" {
#    connection {
#      host = self.public_ip
#      user = "ec2-user"
#      private_key = "${file("~/.ssh/${local.PemFile}.pem")}"
#    }
#    inline = [
#      "echo 'repository set'",
#      "sudo yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm -y",
#      "sudo yum update -y"
#    ]
#  }
  ## ANSIBLE playbook 을 삽입하는 경우 여기를 수정한다.
#  provisioner "local-exec" {
#    command = "echo '[inventory] \n${self.public_ip}' > ./inventory"
#  }
#  provisioner "local-exec" {
#    command = "ansible-playbook --private-key='~/.ssh/dyheo-histech-2.pem' -i inventory monolith.yml"
#  }
}

## EC2 를 만들면 public ip 를 print 해준다.
output "instance-public-ip" {
  value = "${aws_instance.dyheo-ec2.*.public_ip}"
}


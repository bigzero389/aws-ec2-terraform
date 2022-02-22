# AWS용 프로바이더 구성
provider "aws" {
  profile = "default"
  region = "ap-northeast-2"
}

# 기본적으로 원하는 tag 값을 셋팅한다. 
# 단, 아래 세가지 태그는 계속 사용되므로 삭제시 확인 필요
variable "tagging" {
  type = map
  default = {
    Service = "k8s"
    Creator = "dyheo"
    Group = "consulting"
    Name = "dy-bastion"
  }
}

locals {
  # 내가 사용할 pem 파일명을 지정한다. pem 파일은 aws 에서 ec2 의 키 페어에서 미리 만들어서 보관하고 있어야 한다.
  pem_file = "dyheo-histech"

  ## EC2 를 만들기 위한 로컬변수 선언
  ami = "ami-0e4a9ad2eb120e054" ## AMAZON LINUX 2
  instance_type = "t2.micro"    ## 타입은 t2.micro
}

## TAG NAME 으로 vpc id 를 가져온다.
data "aws_vpc" "this" {
  filter {
    name = "tag:Name"
    values = ["${var.tagging["Service"]}-vpc"]
  }
}

## TAG NAME 으로 security group 을 가져온다.
data "aws_security_group" "sg-core" {
  vpc_id = "${data.aws_vpc.this.id}"
  filter {
    name = "tag:Name"
    values = ["${var.tagging["Service"]}-sg-core"]
  }
}

## TAG NAME 으로 subnet 을 가져온다.
data "aws_subnets" "public" {
#  vpc_id = "${data.aws_vpc.this.id}"
  filter {
    name = "tag:Name"
    values = ["${var.tagging["Service"]}-sb-public-*"]
  }
}

data "aws_subnet" "public" {
  for_each = toset(data.aws_subnets.public.ids)
  id       = each.value
}

# AWS Security Group
#resource "aws_security_group" "sg" {
#  name        = "HISTECH-bastion-dyheo-sg"
#  description = "HISTECH bastion for dyheo by terraform"
#  vpc_id      = "${data.aws_vpc.selected.id}"
#
#  ingress = [
#    {
#      description      = "SSH open"
#      from_port        = 22
#      to_port          = 22
#      protocol         = "tcp"
#      type             = "ssh"
#      cidr_blocks      = ["125.177.68.23/32", "211.206.114.80/32"] ## ssh 로 접속할 공인IP 를 지정한다.
#      #cidr_blocks      = ["211.206.114.80/32"]
#      ipv6_cidr_blocks = ["::/0"]
#      prefix_list_ids  = []
#      security_groups  = []
#      self = false
#    }
#  ]
#
#  egress = [
#    {
#      from_port        = 0
#      to_port          = 0
#      protocol         = "-1"
#      cidr_blocks      = ["0.0.0.0/0"]
#      ipv6_cidr_blocks = ["::/0"]
#      prefix_list_ids  = []
#      security_groups  = []
#      self = false
#      description = "outbound all"
#    }
#  ]
#
#  tags = {
#    Name = "${var.tagging["name"]}-sg",
#    Creator= "${var.tagging["creator"]}",
#    Group = "${var.tagging["group"]}"
#  }
#}

# AWS EC2
resource "aws_instance" "bastion" {
  associate_public_ip_address = true  ## ec2 의 public ip 를 활성화한다.

  ami = "${local.ami}"
  instance_type = "${local.instance_type}"
  key_name = "${local.pem_file}"

  subnet_id = element(tolist(data.aws_subnet.public.id), 0)
  #subnet_id = "${data.aws_subnet.public[0].id}"
  vpc_security_group_ids = ["${data.aws_security_group.sg-core.id}"]

  tags = {
    ## 이부분이 나중에 ec2 instance name 으로 된다. ansible 에서는 찾을 때 앞에 언더바 '_' 가 붙는것에 주의.
    Name = "${var.tagging["Name"]}",
    Service = "${var.tagging["Service"]}",
    Creator= "${var.tagging["Creator"]}",
    Group = "${var.tagging["Group"]}"
  }

## 만일 Ansible 을 사용하지 않고 Terraform 만으로 ec2 를 구성하는 경우,
## ec2 의 user data 부분을 아래처럼 삽입하여 간단한 preconfing 를 구성할 수도 있다.
  ## EC2 preconfig
#  provisioner "remote-exec" {
#    connection {
#      host = self.public_ip
#      user = "ec2-user"
#      private_key = "${file("~/.ssh/${local.pem_file}.pem")}"
#    }
#    inline = [
       # epel repository setting
#      "echo 'repository set'",
#      "sudo yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm -y",
#      "sudo yum update -y"
#    ]
#  }

  ## ANSIBLE playbook 을 통합 하는 경우 여기를 수정한다.
#  provisioner "local-exec" {
#    command = "echo 'Terraform finished and Ansible running'"
#  }
#  provisioner "local-exec" {
#    command = "ansible-playbook ./bastion.yml"
#  }
}

## EC2 를 만들면 public ip 를 print 해준다.
output "instance-public-ip" {
  value = "${aws_instance.bastion.public_ip}"
}


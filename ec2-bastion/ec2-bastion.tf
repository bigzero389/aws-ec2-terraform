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
  #ami = "ami-0e4a9ad2eb120e054" ## AMAZON LINUX 2
  #instance_type = "t2.micro"    ## 타입은 t2.micro
  ami = "ami-00632d95bb5b7136d"  ## AMAZON LINUX 2 ARM
  instance_type = "t4g.micro"    ## vCPU : 2, GiB : 1

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
data "aws_subnet" "selected" {
  filter {
    name = "tag:Name"
    values = ["${var.tagging["Service"]}-sb-public-a"]
  }
}

## AWS EC2
resource "aws_instance" "bastion" {
  associate_public_ip_address = true  ## ec2 의 public ip 를 활성화한다.

  ami = "${local.ami}"
  instance_type = "${local.instance_type}"
  key_name = "${local.pem_file}"

  subnet_id = data.aws_subnet.selected.id
  vpc_security_group_ids = ["${data.aws_security_group.sg-core.id}"]

  tags = {
    ## 이부분이 나중에 ec2 instance name 으로 된다. ansible 에서는 찾을 때 앞에 언더바 '_' 가 붙는것에 주의.
    Name = "${var.tagging["Name"]}-${var.tagging["Service"]}",
    Service = var.tagging["Service"],
    Creator= var.tagging["Creator"],
    Group = var.tagging["Group"]
  }
}

## EC2 를 만들면 public ip 를 print 해준다.
output "instance-public-ip" {
  value = "${aws_instance.bastion.public_ip}"
}


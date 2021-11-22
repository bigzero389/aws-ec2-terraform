# AWS용 프로바이더 구성
## reference site : https://rampart81.github.io/post/lb_terraform/
provider "aws" {
  profile = "default"
  region = "ap-northeast-2"
}

locals {
  svc_nm = "dy-ec2"
  creator = "dyheo"
  group = "t-dyheo"

  pem_file = "dyheo-histech"

  ## EC2 를 만들기 위한 로컬변수 선언
  ami = "ami-0e4a9ad2eb120e054" ## AMAZON LINUX 2
  instance_type = "t3.micro"

## Application Service Port
  service_port = 3000
}

data "aws_route53_zone" "histech_dot_net" {
  name = "hist-tech.net."
}

data "aws_lb" "selected" {
  name = "${local.svc_nm}-lb-ec2"
}

resource "aws_route53_record" "public_dyheo" {
  zone_id = "${data.aws_route53_zone.histech_dot_net.zone_id}"
  name    = "dy-ec2.hist-tech.net"
  type    = "A"

  alias {
    name     = "${data.aws_lb.selected.dns_name}"
    zone_id  = "${data.aws_lb.selected.zone_id}"
    evaluate_target_health = true
  }
}

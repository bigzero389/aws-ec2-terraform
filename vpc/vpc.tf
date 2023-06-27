# AWS용 프로바이더 구성
provider "aws" {
  profile = "default"
  #region = "ap-northeast-2"
  region = "ap-northeast-1"
}

data "aws_region" "current" {}

## 신규 VPC 를 구성하는 경우 Owner 과 PemFile 를 새로 넣어야 한다.
locals {
  Region = "${data.aws_region.current.name}"
  CidrPrefix = "10.75"
  Owner = "dy"
  Creator = "dyheo"
  Group = "cloudteam"

  #PemFile = "dyheo-histech"
  PemFile = "dy-tokyo-key"

  public_subnets = {
    "${local.Region}a" = "${local.CidrPrefix}.101.0/24"
#    "${local.Region}b" = "${local.CidrPrefix}.102.0/24"
    "${local.Region}c" = "${local.CidrPrefix}.103.0/24"
  }
  private_subnets = {
    "${local.Region}a" = "${local.CidrPrefix}.111.0/24"
#    "${local.Region}b" = "${local.CidrPrefix}.112.0/24"
    "${local.Region}c" = "${local.CidrPrefix}.113.0/24"
  }
  azs = {
    "${local.Region}a" = "a"
#    "${local.Region}b" = "b"
    "${local.Region}c" = "c"
  }
}

resource "aws_vpc" "this" {
  ## cidr 를 지정해야 한다.
  cidr_block = "${local.CidrPrefix}.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.Owner}-vpc",
    Creator= "${local.Creator}",
    Group = "${local.Group}"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = "${aws_vpc.this.id}"

  tags = {
    Name = "${local.Owner}-igw",
    Creator= "${local.Creator}",
    Group = "${local.Group}"
  }
}

resource "aws_subnet" "public" {
  count      = "${length(local.public_subnets)}"
  cidr_block = "${element(values(local.public_subnets), count.index)}"
  vpc_id     = "${aws_vpc.this.id}"

  map_public_ip_on_launch = true
  availability_zone       = "${element(keys(local.public_subnets), count.index)}"

  tags = {
    Name = "${local.Owner}-sb-public-${element(values(local.azs), count.index)}",
    Creator= "${local.Creator}",
    Group = "${local.Group}"
  }
}

resource "aws_subnet" "private" {
  count      = "${length(local.private_subnets)}"
  cidr_block = "${element(values(local.private_subnets), count.index)}"
  vpc_id     = "${aws_vpc.this.id}"

  map_public_ip_on_launch = true
  availability_zone       = "${element(keys(local.private_subnets), count.index)}"

  tags = {
    Name = "${local.Owner}-sb-private-${element(values(local.azs), count.index)}",
    Creator= "${local.Creator}",
    Group = "${local.Group}"
  }
}

resource "aws_default_route_table" "public" {
  default_route_table_id = "${aws_vpc.this.main_route_table_id}"

  tags = {
    Name = "${local.Owner}-public",
    Creator= "${local.Creator}",
    Group = "${local.Group}"
  }
}

resource "aws_route" "public_internet_gateway" {
  count                  = "${length(local.public_subnets)}"
  route_table_id         = "${aws_default_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.this.id}"

  timeouts {
    create = "5m"
  }
}

resource "aws_route_table_association" "public" {
  count          = "${length(local.public_subnets)}"
  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_default_route_table.public.id}"
}

resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.this.id}"

  tags = {
    Name = "${local.Owner}-private",
    Creator= "${local.Creator}",
    Group = "${local.Group}"
  }
}

resource "aws_route_table_association" "private" {
  count          = "${length(local.private_subnets)}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${aws_route_table.private.id}"
}

resource "aws_eip" "nat" {
  vpc = true

  tags = {
    Name = "${local.Owner}-eip",
    Creator= "${local.Creator}",
    Group = "${local.Group}"
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = "${aws_eip.nat.id}"
  subnet_id     = "${aws_subnet.public.0.id}"

  tags = {
    Name = "${local.Owner}-nat-gw",
    Creator= "${local.Creator}",
    Group = "${local.Group}"
  }
}

resource "aws_route" "private_nat_gateway" {
  route_table_id         = "${aws_route_table.private.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${aws_nat_gateway.this.id}"

  timeouts {
    create = "5m"
  }
}


# AWS Security Group
resource "aws_security_group" "sg-core" {
  name        = "${local.Owner}-sg-core"
  description = "${local.Owner} security group"
  vpc_id      = "${aws_vpc.this.id}"

  ingress = [
    {
      description      = "ping"
      from_port = -1
      to_port = -1
      protocol = "icmp"
      cidr_blocks      = ["125.177.68.23/32", "211.206.114.80/32", "${local.CidrPrefix}.0.0/16"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self = false
    },
    {
      description      = "SSH open"
      from_port        = 22
      to_port          = 22
      type             = "ssh"
      protocol         = "tcp"
      cidr_blocks      = ["125.177.68.23/32", "211.206.114.80/32", "${local.CidrPrefix}.0.0/16"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self = false
    },
     {
       description      = "HTTP open"
       from_port        = 80 
       to_port          = 80
       protocol         = "tcp"
       cidr_blocks      = ["125.177.68.23/32", "211.206.114.80/32", "${local.CidrPrefix}.0.0/16"]
       #cidr_blocks      = ["0.0.0.0/0"]
       ipv6_cidr_blocks = []
       prefix_list_ids  = []
       security_groups  = []
       self = false
     },
     {
       description      = "HTTPS open"
       from_port        = 443
       to_port          = 443
       protocol         = "tcp"
       cidr_blocks      = ["125.177.68.23/32", "211.206.114.80/32", "${local.CidrPrefix}.0.0/16"]
       ipv6_cidr_blocks = []
       prefix_list_ids  = []
       security_groups  = []
       self = false
     },
     {
       description      = "redis"
       from_port        = 6379
       to_port          = 6379
       protocol         = "tcp"
       cidr_blocks      = ["125.177.68.23/32", "211.206.114.80/32", "${local.CidrPrefix}.0.0/16"]
       ipv6_cidr_blocks = []
       prefix_list_ids  = []
       security_groups  = []
       self = false
     }
  ]

  egress = [
    {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self = false
      description = "outbound all"
    }
  ]

  tags = {
    Name = "${local.Owner}-sg-core",
    Creator= "${local.Creator}",
    Group = "${local.Group}"
  }
}


output "aws_vpc" {
  value = aws_vpc.this.id
}



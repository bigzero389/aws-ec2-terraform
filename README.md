# AWS 를 이용한 Terraform Example
* 사전준비사항  
  * AWS IAM 계정이 있어야 한다.   
    AWS CLI([download](https://docs.aws.amazon.com/ko_kr/cli/latest/userguide/install-cliv2-windows.html)) 와 Access/Secret Key 셋팅이 되어 있어야 한다.  
  * EC2 의 key pair 가 있어야 한다.
    Local PC 에 ~/.ssh 에 key pair pem 파일이 있어야 한다.   
    window os 에서 pem 사용하기 ([reference](https://techsoda.net/windows10-pem-file-permission-settings/))  
  * Local PC 에 Terraform 이 설치되어 있어야 한다.([download](https://www.terraform.io/downloads.html))    
  * Git Client 가 설치되어 있어야 한다. ([download](https://git-scm.com/download))
  * github 연결을 위한 ssh key 가 있어야 한다. OpenSSH client 가 있으면 ssh-keygen 을 실행하여 key 를 생성한다.

## Terraform 기본 사용법
```
terraform init
terraform validate
terraform plan 
terraform apply [--auto-approve]
terraform destroy [--auto-approve]
```
* 테라폼 파일을 정해진 폴더에 만든다. 확장자는 tf 이다.
* tf 파일이 있는 경로에서 terraform init 를 실행한다. .terraform 숨김폴더가 생성된다.
* terraform validate 를 하여 문법적인 오류를 확인한다.
* terraform plan 을 하면 처리할 계획을 만들어서 보여준다. 지정된 변수등이 정확히 나오는지 확인한다.
* terraform apply 를 하면 스크립트가 실행된다. yes 를 입력하여 실행할지 여부를 이중 체크한다.
* terraform destroy 하면 해당 자원을 모두 삭제한다.

## 순서
* vpc => ec2 => db => ec2-lb
* db 는 시간이 오래 소요됨. ssl disable 에서 접속해야 함.
* all , s3 는 별도임.

## 폴더구성
### vpc
* VPC 환경만 구성한다.
* 기본적인 네트워크 환경들도 구성한다. 즉, all 에서 EC2 만 제외하고 구성된다.
* destroy 하면 VPC 가 전체 삭제된다. 이때 vpc terraform 으로 만들어지지 않은 다른 자원들이 종속되어 있으면 삭제가 안된다.
* 위에 all 에서 변경해야 되는 부분들을 변경하고 실행한다.

### ec2
* 지정된 tag 이름으로 만들어진 VPC 정보에 기반하여 EC2 만 생성한다. 
* destroy 하면 해당 EC2 를 삭제한다.
* 보안그룹을 여기서 설정하게 작업했음.

* 아래 부분을 자기 환경에 맞는 값으로 수정해서 실행한다.
```
locals {
  svc_nm = "dyheo"
  pem_file = "dyheo-histech-2"
```
[terraform example reference](https://github.com/largezero/ecs-with-codepipeline-example-by-terraform).  
* aws cli 를 이용하여 ami list 가져오기
```
aws ec2 describe-images \ 
--filters Name=architecture,Values=x86_64 Name=name,Values="amzn2-ami-ecs-hvm-*"
```

### db
* db module 을 사용한다.
* 삭제시 module 이 정상작동 하지 않는 문제가 있는 것으로 추정됨

### ec2-lb


### all
* VPC 를 구성하고 EC2 를 한대 만든다.
* destroy 하면 VPC 및 EC2 등 모든 자원이 삭제된다.

* 아래 "svc_nm"과 "pem_file" 을 적절한 값으로 변경한다.
```
 ...
locals {
  ## 신규 VPC 를 구성하는 경우 svc_nm 과 pem_file 를 새로 넣어야 한다.
  svc_nm = "dyheo"
  pem_file = "dyheo-histech-2"
 ...
```
* 아래 cidr_blocks 에 본인이 ssh 로 접속할 공인IP 로 변경한다.
```
{
  description      = "SSH from home"
  from_port        = 22
  to_port          = 22
  protocol         = "tcp"
  type             = "ssh"
  cidr_blocks      = ["125.177.68.23/32", "211.206.114.80/32"]
  ipv6_cidr_blocks = ["::/0"]
  prefix_list_ids  = []
  security_groups  = []
  self = false
}

```


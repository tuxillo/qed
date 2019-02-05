/*
   Copyright 2018 Banco Bilbao Vizcaya Argentaria, S.A.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

data "http" "ip" {
  url = "http://icanhazip.com"
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_key_pair" "qed" {
  key_name   = "qed"
  public_key = "${file("${var.keypath}.pub")}"
}

data "aws_subnet_ids" "all" {
  vpc_id = "${data.aws_vpc.default.id}"
}

module "security_group" {
  source = "terraform-aws-modules/security-group/aws"
  version = "2.11.0"

  name        = "qed"
  description = "Security group for QED usage"
  vpc_id      = "${data.aws_vpc.default.id}"

  egress_rules        = ["all-all"]

  ingress_cidr_blocks = ["${chomp(data.http.ip.body)}/32"]
  ingress_rules       = ["all-icmp", "ssh-tcp" ]
  ingress_with_cidr_blocks = [
    {
      from_port       = 8800
      to_port         = 8800
      protocol        = "tcp"
      cidr_blocks     = "${chomp(data.http.ip.body)}/32"
    },
    {
      from_port       = 8600
      to_port         = 8600
      protocol        = "tcp"
      cidr_blocks     = "${chomp(data.http.ip.body)}/32"
    },
    {
      from_port       = 6060
      to_port         = 6060
      protocol        = "tcp"
      cidr_blocks     = "${chomp(data.http.ip.body)}/32"
    },
    {
      from_port       = 9100
      to_port         = 9100
      protocol        = "tcp"
      cidr_blocks     = "${chomp(data.http.ip.body)}/32"
    }
  ]
  computed_ingress_with_source_security_group_id = [
    {
      from_port       = 0
      to_port         = 65535
      protocol        = "tcp"
      source_security_group_id  = "${module.security_group.this_security_group_id}"
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1

}

module "prometheus_security_group" {
  source = "terraform-aws-modules/security-group/aws"
  version = "2.11.0"

  name        = "prometheus"
  description = "Security group for Prometheus/Grafana usage"
  vpc_id      = "${data.aws_vpc.default.id}"

  egress_rules        = ["all-all"]

  ingress_cidr_blocks = ["${chomp(data.http.ip.body)}/32"]
  ingress_rules       = ["all-icmp", "ssh-tcp" ]
  ingress_with_cidr_blocks = [
    {
      from_port       = 9090
      to_port         = 9090
      protocol        = "tcp"
      cidr_blocks     = "${chomp(data.http.ip.body)}/32"
    },
    {
      from_port       = 3000
      to_port         = 3000
      protocol        = "tcp"
      cidr_blocks     = "${chomp(data.http.ip.body)}/32"
    },
  ]
  computed_ingress_with_source_security_group_id = [
    {
      from_port       = 0
      to_port         = 65535
      protocol        = "tcp"
      source_security_group_id  = "${module.security_group.this_security_group_id}"
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1

}
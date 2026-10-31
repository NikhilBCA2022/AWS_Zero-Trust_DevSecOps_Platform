variable "name_prefix" {
  description = "Prefix used to name runner and NAT resources"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to AWS resources"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "ID of the existing Zero-Trust VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the existing VPC"
  type        = string
}

variable "public_subnet_id" {
  description = "Existing public subnet ID hosting the NAT instance"
  type        = string
}

variable "runner_subnet_id" {
  description = "Dedicated private subnet ID for the self-hosted runner"
  type        = string
}

variable "runner_route_table_id" {
  description = "Dedicated route table ID for the runner subnet"
  type        = string
}

variable "nat_instance_type" {
  description = "EC2 instance type for the NAT instance"
  type        = string
  default     = "t3.micro"
}

variable "runner_instance_type" {
  description = "EC2 instance type for the self-hosted GitHub Actions runner"
  type        = string
  default     = "t3.medium"
}

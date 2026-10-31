resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-igw"
  })
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-public-${count.index + 1}"
    Tier = "Public"
  })
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-private-${count.index + 1}"
    Tier = "Private"
  })
}
resource "aws_subnet" "database" {
  count = length(var.database_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.database_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-database-${count.index + 1}"
    Tier = "Database"
  })
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-public-rt"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-private-rt"
  })
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-database-rt"
    Tier = "Database"
  })
}

resource "aws_route_table_association" "database" {
  count = length(aws_subnet.database)

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}
# Dedicated private subnet for the self-hosted GitHub Actions runner.
resource "aws_subnet" "runner" {
  count = (
    var.runner_subnet_cidr != "" &&
    var.runner_subnet_az != ""
  ) ? 1 : 0

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.runner_subnet_cidr
  availability_zone       = var.runner_subnet_az
  map_public_ip_on_launch = false

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-runner"
    Tier = "Private-Runner"
  })
}

# Dedicated route table so runner routing does not change existing private routes.
resource "aws_route_table" "runner" {
  count  = length(aws_subnet.runner)
  vpc_id = aws_vpc.this.id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-runner-rt"
    Tier = "Private-Runner"
  })
}

resource "aws_route_table_association" "runner" {
  count = length(aws_subnet.runner)

  subnet_id      = aws_subnet.runner[count.index].id
  route_table_id = aws_route_table.runner[count.index].id
}

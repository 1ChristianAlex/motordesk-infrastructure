resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  count                   = length(local.availability_zones)
  vpc_id                  = aws_vpc.main.id
  availability_zone       = local.availability_zones[count.index]
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true

  tags = {
    "kubernetes.io/role/elb"                          = "1"
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "shared"
  }
}

resource "aws_subnet" "app" {
  count             = length(local.availability_zones)
  vpc_id            = aws_vpc.main.id
  availability_zone = local.availability_zones[count.index]
  cidr_block        = var.app_subnet_cidrs[count.index]
}

resource "aws_subnet" "data" {
  count             = length(local.availability_zones)
  vpc_id            = aws_vpc.main.id
  availability_zone = local.availability_zones[count.index]
  cidr_block        = var.data_subnet_cidrs[count.index]
}

resource "aws_eip" "nat" {
  count  = var.environment == "prod" ? length(local.availability_zones) : 1
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  count         = var.environment == "prod" ? length(local.availability_zones) : 1
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count          = length(local.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "app" {
  count  = length(local.availability_zones)
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "app_nat" {
  count                  = length(local.availability_zones)
  route_table_id         = aws_route_table.app[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[var.environment == "prod" ? count.index : 0].id
}

resource "aws_route_table_association" "app" {
  count          = length(local.availability_zones)
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app[count.index].id
}

resource "aws_route_table" "data" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table_association" "data" {
  count          = length(local.availability_zones)
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}

resource "aws_security_group" "mongo_efs" {
  name        = "${var.project_name}-${var.environment}-mongo-efs"
  description = "NFS access only from EKS worker nodes."
  vpc_id      = aws_vpc.main.id

  egress = []
}

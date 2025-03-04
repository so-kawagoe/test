# VPC
resource "aws_vpc" "gpt_api_kawagoe" {
  cidr_block = "192.168.0.0/24"

  tags = {
    Name = "gpt-api-kawagoe"
  }
}

# サブネット 1
resource "aws_subnet" "gpt_api_kawagoe_public_subnet_1a" {
  vpc_id     = aws_vpc.gpt_api_kawagoe.id
  cidr_block = "192.168.0.0/25"

  tags = {
    Name = "gpt-api-kawagoe-public-subnet-1a"
  }
}

# サブネット 2
resource "aws_subnet" "gpt_api_kawagoe_public_subnet_1c" {
  vpc_id     = aws_vpc.gpt_api_kawagoe.id
  cidr_block = "192.168.0.128/25"

  tags = {
    Name = "gpt-api-kawagoe-public-subnet-1c"
  }
}

# インターネットゲートウェイ
resource "aws_internet_gateway" "gpt_api_kawagoe_igw" {
  vpc_id = aws_vpc.gpt_api_kawagoe.id

  tags = {
    Name = "gpt-api-kawagoe-igw"
  }
}

# ルートテーブル
resource "aws_route_table" "gpt_api_kawagoe_rt" {
  vpc_id = aws_vpc.gpt_api_kawagoe.id

  tags = {
    Name = "gpt-api-kawagoe-rt"
  }
}

# ルートテーブルをサブネット1，2に関連付け
resource "aws_route_table_association" "gpt_api_kawagoe_rta_public" {
  for_each = {
    "1a" = aws_subnet.gpt_api_kawagoe_public_subnet_1a.id
    "1c" = aws_subnet.gpt_api_kawagoe_public_subnet_1c.id
  }

  subnet_id      = each.value
  route_table_id = aws_route_table.gpt_api_kawagoe_rt.id
}

# ルートテーブルにルートを追加
resource "aws_route" "gpt_api_kawagoe_r_public" {
  route_table_id         = aws_route_table.gpt_api_kawagoe_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gpt_api_kawagoe_igw.id
}

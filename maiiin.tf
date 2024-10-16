terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.69"
    }
  }

  backend "s3" {
    bucket = "terraform-state-bucket"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

# Create a VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "My-VPC"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "My-IGW"
  }
}
# Public Subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public-Subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public-Subnet-2"
  }
}

# Private Subnets
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Private-Subnet-1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Private-Subnet-2"
  }
}
# Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public-RT"
  }
}

# Associate Route Table with Public Subnets
resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}
# Web Server Security Group
resource "aws_security_group" "web_sg" {
  name   = "web-server-sg"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web-SG"
  }
}

# App Server Security Group
resource "aws_security_group" "app_sg" {
  name   = "app-server-sg"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "App-SG"
  }
}

# Database Server Security Group
resource "aws_security_group" "db_sg" {
  name   = "db-server-sg"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.11.0/24", "10.0.12.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "DB-SG"
  }
}
resource "aws_key_pair" "web_key" {
  key_name   = "web-server-key"
  public_key = file("~/.ssh/web-server.pub")
}

resource "aws_key_pair" "app_key" {
  key_name   = "app-server-key"
  public_key = file("~/.ssh/app-server.pub")
}

resource "aws_key_pair" "db_key" {
  key_name   = "db-server-key"
  public_key = file("~/.ssh/db-server.pub")
}
# Web Server Instances
resource "aws_instance" "web_server_1" {
  ami                    = "ami-0d5eff06f840b45e9"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet_1.id
  key_name               = aws_key_pair.web_key.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  user_data              = "${file("apache.sh")}

  tags = {
    Name = "Web-Server-1"
  }
}

resource "aws_instance" "web_server_2" {
  ami                    = "ami-0d5eff06f840b45e9"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet_2.id
  key_name               = aws_key_pair.web_key.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  user_data              = "${file("apache.sh")}

  tags = {
    Name = "Web-Server-2"
  }
}

# App Server Instances
resource "aws_instance" "app_server_1" {
  ami                    = "ami-0d5eff06f840b45e9"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet_1.id
  key_name               = aws_key_pair.app_key.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  tags = {
    Name = "App-Server-1"
  }
}

resource "aws_instance" "app_server_2" {
  ami                    = "ami-0d5eff06f840b45e9"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet_2.id
  key_name               = aws_key_pair.app_key.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  tags = {
    Name = "App-Server-2"
  }
}

# Database Server Instances
resource "aws_instance" "db_server_1" {
  ami                    = "ami-0d5eff06f840b45e9"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet_1.id
  key_name               = aws_key_pair.db_key.key_name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  tags = {
    Name = "DB-Server-1"
  }
}

resource "aws_instance" "db_server_2" {
  ami                    = "ami-0d5eff06f840b45e9"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet_2.id
  key_name               = aws_key

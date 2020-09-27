# Login to AWS

provider "aws" {
	region 				= "ap-south-1"
	profile 			= "arpit"
}



# Creating the VPC

resource "aws_vpc" "arpit-vpc" {
	cidr_block 			 = "192.168.0.0/16"
	instance_tenancy 	 = "default"
	enable_dns_hostnames = "true"
	
	tags = {
		Name = "arpit-vpc"
	}
}



# Creating Subnet

# Public Subnet
resource "aws_subnet" "pub-subnet" {
	depends_on 			= [ aws_vpc.arpit-vpc ,]
	
	vpc_id 				= aws_vpc.arpit-vpc.id
	cidr_block 			= "192.168.0.0/24"
	availability_zone 	= "ap-south-1a"
	map_public_ip_on_launch  = "true"
	
	tags = {
		Name = "pub-subnet"
	}
}


# Private Subnet
resource "aws_subnet" "pri-subnet" {
	depends_on 			= [ aws_vpc.arpit-vpc ,]
	
	vpc_id 				= aws_vpc.arpit-vpc.id
	cidr_block 			= "192.168.1.0/24"
	availability_zone 	= "ap-south-1b"
	
	tags = {
		Name = "pri-subnet"
	}
}



# Creating Internet Gateway

resource "aws_internet_gateway" "arpit-ig" {
	depends_on 			= [ aws_vpc.arpit-vpc ,]
	
	vpc_id 				= aws_vpc.arpit-vpc.id
	
	tags = {
		Name = "arpit-ig"
	}
}



# Creating Route Table for Internet Gateway for Public Access

resource "aws_route_table" "arpit-rt" {
	depends_on 			= [ aws_vpc.arpit-vpc ,]
	
	vpc_id 			    = aws_vpc.arpit-vpc.id
	route {
		cidr_block 		= "0.0.0.0/0"
		gateway_id 		= aws_internet_gateway.arpit-ig.id
    }
  
	tags = {
		Name = "arpit-rt"
	}
}


# Association of Route table to Public Subnet

resource "aws_route_table_association" "pub-subnet-rt" {
	depends_on 			= [ aws_route_table.arpit-rt , aws_subnet.pub-subnet ]
	
	subnet_id 			= aws_subnet.pub-subnet.id
	route_table_id 		= aws_route_table.arpit-rt.id
}




# Generating Key pair

resource "tls_private_key" "key-pair" {
	algorithm 			= "RSA"
}

resource "aws_key_pair" "key" {
	depends_on 			= [ tls_private_key.key-pair ,]
	
	key_name 			= "arpitT1"
	public_key 			= tls_private_key.key-pair.public_key_openssh
}	



# Creating Security Group for WordPress

resource "aws_security_group" "wp-sg" {
	depends_on 			= [ aws_vpc.arpit-vpc ,]
	
	name        		= "wp-allow"
	description 		= "https and ssh"
	vpc_id      		= aws_vpc.arpit-vpc.id

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
		Name ="wp-allow"
	}
}


# Creating Security Group for MySQL

resource "aws_security_group" "msql-sg" {
	depends_on 			= [ aws_vpc.arpit-vpc ,]
	
	name        	= "msql-allow"
	description 	= "mysql-allow-port-3306"
	vpc_id      	= aws_vpc.arpit-vpc.id

	ingress {
		from_port   = 3306
		to_port     = 3306
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
		Name =	"msql-allow"
	}
}




# Launch WordPress Instance

resource "aws_instance" "wp-os" {
	depends_on 			= [ aws_subnet.pub-subnet , aws_security_group.wp-sg]
	
	ami                	= "ami-7e257211" 
    instance_type      	= "t2.micro"
    key_name       	   	= aws_key_pair.key.key_name
    security_groups	 	= [aws_security_group.wp-sg.id ,]
    subnet_id       	= aws_subnet.pub-subnet.id
 
	tags = {
		Name = "wp-os"
	}
}


# Launching MySQL Instance

resource "aws_instance" "mysql-os" {
	depends_on 			= [ aws_subnet.pri-subnet , aws_security_group.msql-sg]
	
	ami           		= "ami-08706cb5f68222d09"
	instance_type 		= "t2.micro"
	key_name 			= aws_key_pair.key.key_name
	security_groups 	= [aws_security_group.msql-sg.id ,]
	subnet_id 			= aws_subnet.pri-subnet.id
 
	tags = {
		Name = "mysql-os"
	}
}


# Get public IP of WordPress

output "wordpress-ip" {
	value 				= aws_instance.wp-os.public_ip
}


# Connect to the WordPress

resource "null_resource" "open-wp"  {

depends_on = [aws_instance.wp-os, aws_instance.mysql-os]

	provisioner "local-exec" {
	    command = "start chrome ${aws_instance.wp-os.public_ip}"
  	}
}

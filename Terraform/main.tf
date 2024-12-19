
provider "aws" { 
  profile = "default"
  region  = "us-east-2"
}

# Creating a New Key
resource "aws_key_pair" "Key-Pair" {

  # Name of the Key
  key_name = "MyKey"

  # Adding the SSH authorized key !
 public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDIQm2jeFj2XW06UO4OYfUSf6FJzS/xDoU5wrXKaDUpifE+yWbGTSOo9/sIx8B9BB7twCe+HO1Y7v4Til3TNicQ/EMr3HkI4PvGpO1ahedHhN4HQoh78mq82yCWa9uXebcOtjCW9lP3DCQcAx7qk2hfF7rlm2sX9JCCMZfY7G5qduVpnKnbhW8w/DyrruXKbPlA2TTyvHT/LpRNat63Gi85jpHR4gUZcN6lqnJr1Yyv423Bk2QLz6gtdwa8Znjah/0gxsxTVwGwE8qfr2TlX04jZCXpvdcufbC0z0ne5SXXBKHhnsGDSuMJLVraW+VDGi3D8Cy6JxHYw2INqCfY6OzGqXZN/6UuBcLJ/IJg1RRyy7JKe7uztNVKNzAUm3vtoG/S6jHqIihH0gnexi3w4vDDwmnPIf7VVgdGujpscNB4KYhy1+pQ2mpSdVrj1OIXscuUuvwohjNZbigM0CO6xbscG26QdyTk6pspg5LJCPV2NdTJ9Y1VPM2jyRoNgVJf/xs= shivakumar@shivas-MacBook-Air.local"

}


# Creating a VPC!
resource "aws_vpc" "prod" {

  # IP Range for the VPC
  cidr_block = "178.21.0.0/16"

  # Enabling automatic hostname assigning
  enable_dns_hostnames = true
  tags = {
    Name = "prod"
  }
}


# Creating Public subnet!
resource "aws_subnet" "subnet1" {
  depends_on = [
    aws_vpc.prod
  ]

  # VPC in which subnet has to be created!
  vpc_id = aws_vpc.prod.id

  # IP Range of this subnet
  cidr_block = "178.21.10.0/24"

  # Data Center of this subnet.
  availability_zone = "us-east-2a"

  # Enabling automatic public IP assignment on instance launch!
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet"
  }
}



# Creating an Internet Gateway for the VPC
resource "aws_internet_gateway" "Internet_Gateway" {
  depends_on = [
    aws_vpc.prod,
    aws_subnet.subnet1,
  ]

  # VPC in which it has to be created!
  vpc_id = aws_vpc.prod.id

  tags = {
    Name = "IG-Public-&-Private-VPC"
  }
}

# Creating an Route Table for the public subnet!
resource "aws_route_table" "Public-Subnet-RT" {
  depends_on = [
    aws_vpc.prod,
    aws_internet_gateway.Internet_Gateway
  ]

  # VPC ID
  vpc_id = aws_vpc.prod.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Internet_Gateway.id
  }

  tags = {
    Name = "Route Table for Internet Gateway"
  }
}

# Creating a resource for the Route Table Association!
resource "aws_route_table_association" "RT-IG-Association" {

  depends_on = [
    aws_vpc.prod,
    aws_subnet.subnet1,
    aws_route_table.Public-Subnet-RT
  ]

  # Public Subnet ID
  subnet_id = aws_subnet.subnet1.id

  #  Route Table ID
  route_table_id = aws_route_table.Public-Subnet-RT.id
}

# Creating a Security Group for Jenkins
resource "aws_security_group" "JENKINS-SG" {

  depends_on = [
    aws_vpc.prod,
    aws_subnet.subnet1,
  ]

  description = "HTTP, PING, SSH"

  # Name of the security Group!
  name = "jenkins-sg"

  # VPC ID in which Security group has to be created!
  vpc_id = aws_vpc.prod.id

  # Created an inbound rule for webserver access!
  ingress {
    description = "HTTP for webserver"
    from_port   = 80
    to_port     = 8080

    # Here adding tcp instead of http, because http in part of tcp only!
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Created an inbound rule for ping
  ingress {
    description = "Ping"
    from_port   = 0
    to_port     = 0
    protocol    = "ICMP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Created an inbound rule for SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22

    # Here adding tcp instead of ssh, because ssh in part of tcp only!
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outward Network Traffic for the WordPress
  egress {
    description = "output from webserver"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Creating security group for MyApp, this will allow access only from the instances having the security group created above.
resource "aws_security_group" "MYAPP-SG" {

  depends_on = [
    aws_vpc.prod,
    aws_subnet.subnet1,
    ]

  description = "MyApp Access only from the Webserver Instances!"
  name        = "myapp-sg"
  vpc_id      = aws_vpc.prod.id

  # Created an inbound rule for MyApp
  ingress {
    description     = "MyApp Access"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  #  security_groups = [aws_security_group.JENKINS-SG.id]
  }

  # Created an inbound rule for SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22

    # Here adding tcp instead of ssh, because ssh in part of tcp only!
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "output from MyApp"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Creating an AWS instance for the Jenkins!
resource "aws_instance" "jenkins" {

  depends_on = [
    aws_vpc.prod,
    aws_subnet.subnet1,
    aws_security_group.JENKINS-SG
  ]

  ami = "ami-0b4624933067d393a"

  # amazoon-linux
  instance_type = "t2.large"
  subnet_id     = aws_subnet.subnet1.id

  # Keyname and security group are obtained from the reference of their instances created above!
  # Here I am providing the name of the key which is already uploaded on the AWS console.
  key_name = "MyKey"

  # Security groups to use!
  vpc_security_group_ids = [aws_security_group.JENKINS-SG.id]

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install wget ",
      "sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo",
      "sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key",	    
      "sudo yum upgrade -y",
      "sudo dnf install java-17-amazon-corretto -y",	  
      "sudo yum install jenkins -y",
 	    "sudo systemctl start jenkins",
      "sudo systemctl enable jenkins",
	    "sudo yum install git maven -y",
      "sudo yum install ansible -y",
      "sudo yum install docker -y",
      "sudo service docker start",
      "sudo usermod -aG docker $USER",
      "sudo usermod -aG docker jenkins",
      "sudo systemctl enable docker.service",
      "sudo systemctl enable containerd.service",
      "systemctl restart docker",
      "sudo chmod 666 /var/run/docker.sock",
      "systemctl restart docker",
      "sudo docker run -itd --name sonar -p 9000:9000 sonarqube",
      "sudo rpm -ivh https://github.com/aquasecurity/trivy/releases/download/v0.18.3/trivy_0.18.3_Linux-64bit.rpm",
    ]
  }
  tags = {
    Name = "Jenkins_UTIL_From_Terraform"
  }

}

# Creating an AWS instance for the MyApp! It should be launched in the private subnet!
resource "aws_instance" "MyApp" {
  depends_on = [
    aws_instance.jenkins,
  ]

  # i.e. MyApp Installed!
  ami = "ami-0b4624933067d393a"
  # amazoon-linux
  instance_type = "t2.medium"
  subnet_id     = aws_subnet.subnet1.id

  # Keyname and security group are obtained from the reference of their instances created above!
  key_name = "MyKey"


  # Attaching 2 security groups here, 1 for the MyApp Database access by the Web-servers,
  vpc_security_group_ids = [aws_security_group.MYAPP-SG.id]

  tags = {
    Name = "MyApp_From_Terraform"
  }
}

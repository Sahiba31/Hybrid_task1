provider "aws" {
  region   = "ap-south-1"
  profile  = "sahiba1"
}

variable "Key" {
  type = string
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCTw2R86svZvfChAEBWti6nXn21BTZI2fw23lQolop8CNP8C8jvXt4OzgjjPBMKVn3gkgyhCEDoew573P8I32blHidIg8JJ6YSNK68P9aOpgXv4Ph76MDRdJEqmFFxoiEAz/9Pf3/aREu7e4yfryl5ZuxddN0OaEXW+0c3ixjrHfxBexOF2CK9DWQ/CPBz7A2yrft0SGfr5+UQChjChkTpswPp8cBX6NisFdBa2Yi+wLKc35FwuaLzsT/BDJ5iv8/3TSbJG4B1hQSDPKgVhVcKJje00mCxwbJe/ZBWxEo4ZRDk0QEsSnLtqZGqwOgaO0FY9cAFV6sq0+9JgjjU84SyR"
}

resource "aws_key_pair" "task1_key" {
  key_name   = "task1_key"
  public_key = var.Key
}


resource "aws_security_group" "task1-sg" {
  name        = "task1-sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-af534fc7"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
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
    Name = "task1-sg"
  }

}

resource "aws_instance" "myos1" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  availability_zone = "ap-south-1a"
  key_name = "task1_key"
  security_groups = ["task1-sg"]

  connection {
   type = "ssh"
   user = "ec2-user"
   private_key = file("C:/Users/Sahiba/Downloads/sahiba.pem")
   host = aws_instance.myos1.public_ip
}

  provisioner "remote-exec" {
    inline = [
       "sudo yum install httpd php git -y",
       "sudo systemctl restart httpd",
       "sudo systemctl enable httpd",
      ]
}
  tags = {
    Name = "MyOS1"
  }
}

output "availzone" {
  value = aws_instance.myos1.availability_zone
}


resource "aws_ebs_volume" "myvol" {
  availability_zone = aws_instance.myos1.availability_zone
  type = "gp2"
  size = 1
  tags = {
    Name = "MyVol"
  }

  depends_on = [aws_instance.myos1]
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id = aws_ebs_volume.myvol.id
  instance_id = aws_instance.myos1.id
  force_detach = true
  depends_on = [
      aws_ebs_volume.myvol,
      aws_instance.myos1
   ]
}

output "myip" {
  value = aws_instance.myos1.public_ip
}

resource "null_resource" "nullip" {
  provisioner "local-exec" {
    command = "echo ${aws_instance.myos1.public_ip} > publicip.txt"
  }
}

resource "null_resource" "confweb" {
  depends_on = [
      aws_volume_attachment.ebs_att,
  ]
  connection {
   type = "ssh"
   user = "ec2-user"
   private_key = file("C:/Users/Sahiba/Downloads/sahiba.pem")
   host = aws_instance.myos1.public_ip
}
  provisioner "remote-exec" {
    inline = [
       "sudo mkfs.ext4  /dev/xvdh",
       "sudo mount /dev/xvdh  /var/www/html",
       "sudo rm -rf /var/www/html/*",
       "sudo git clone https://github.com/Sahiba31/Hybrid_task1.git  /var/www/html"
      ]
}
}



resource "aws_s3_bucket" "sahibabbucc1234567899" {
  bucket = "sahiba-bucket1"
  acl    = "public-read"
  force_destroy = "true"
  versioning {
      enabled = true
   }
  tags = {
    Name = "sahiba-bucket1"
  }
}



resource "aws_s3_bucket_object" "s3object" {
  bucket = "sahiba-bucket1"
  key    = "Flower.jpg"
  source = "C:/Users/Sahiba/Desktop/Flower.jpg"
  acl = "public-read"
  content_type = "image/jpg"
  depends_on = [
	aws_s3_bucket.sahibabbucc1234567899,
   ]
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "sahibabbucc1234567899"
}

resource "aws_cloudfront_distribution" "mycloudfront" {
  origin {
     domain_name = "sahiba-bucket1.s3.amazonaws.com"
     origin_id = "S3-sahiba-bucket1"

     custom_origin_config {
        http_port = 80
        https_port = 80
        origin_protocol_policy = "match-viewer"
        origin_ssl_protocols = ["TLSv1", "TLSv1.1" , "TLSv1.2"]
      }
    }
    enabled = true
    is_ipv6_enabled = true

    default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-sahiba-bucket1"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
   }
   
    restrictions {
    geo_restriction {
      restriction_type = "none"
    }
   }
   
    viewer_certificate {
    cloudfront_default_certificate = true
   }
   
   depends_on = [
      aws_s3_bucket_object.s3object
   ]
}
output "domain-name" {
  value = aws_cloudfront_distribution.mycloudfront.domain_name
}

resource "null_resource" "myimage" {
  depends_on = [
     aws_cloudfront_distribution.mycloudfront,
  ]

  provisioner "local-exec" {
  command = "start chrome ${aws_instance.myos1.public_ip}"
   }
}

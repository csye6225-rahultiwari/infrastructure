// EC2 Instance Creation


locals {
  disable_api_termination = false
}

resource "aws_instance" "csye6225-ec2-instance" {

  ami                     = var.ami
  instance_type           = "t2.micro"
  disable_api_termination = local.disable_api_termination
  iam_instance_profile = "${aws_iam_instance_profile.csye6225_profile.name}"
 // key_name = ""

  ebs_block_device {
    device_name           = "/dev/sda1"
    volume_size           = 20
    volume_type           = "gp2"
    delete_on_termination = true
  }
  network_interface {
    network_interface_id = aws_network_interface.my-interface.id
    device_index         = 0
  }


  tags = {
    Name = "csye6225-ec2-instance"
  }

}
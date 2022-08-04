# Get Linux AMI ID using SSM Parameter endpoint in us-east-1
data "aws_ssm_parameter" "linuxAmi" {
  provider = aws.region-master
  name     = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

# Get linux AMI ID using SSM Parameter endpoint in us-west-2
data "aws_ssm_parameter" "linuxAmiOregon" {
  provider = aws.region-worker
  name     = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

# Create key-pair for logging into EC2 in us-east-1
resource "aws_key_pair" "master-key" {
  provider   = aws.region-master
  key_name   = "jenkins"
  public_key = file("/root/.ssh/id_rsa.pub")
}

# Create key-pair for loggin into EC2 in us-west-2
resource "aws_key_pair" "worker-key" {
  provider   = aws.region-worker
  key_name   = "jenkins"
  public_key = file("/root/.ssh/id_rsa.pub")
}

# Create and bootstrap EC2 ins us-east-1
# It only spin up only after the creation of the main route table
resource "aws_instance" "jenkins-master" {
  provider                    = aws.region-master
  ami                         = data.aws_ssm_parameter.linuxAmi.value
  instance_type               = var.instance-type
  key_name                    = aws_key_pair.master-key.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.jenkins-sg.id]
  subnet_id                   = aws_subnet.subnet_1.id

  tags = {
    Name = "jenkins_master_tf"
  }

  depends_on = [aws_main_route_table_association.set-master-default-rt-assoc]

  provisioner "local-exec" {
    command = <<EOF
    aws --profile ${var.profile} ec2 wait instance-status-ok --region ${var.region-master} --instance-ids ${self.id}
    ansible-playbook --extra-vars "passed_in_hosts=tag_Name_${self.tags.Name}" ansible_templates/install_jenkins_master.yml
    EOF
  }

}

# Create EC2 in us-west-2
# count parameter (universal parameter) helps you create multiple resources
# via one resource block in terraform
# We whant to provide a distinct name to each spun up resource
# Count.index increments when the count is encremented
# The first count.index would be 0
resource "aws_instance" "jenkins-worker-oregon" {
  provider                    = aws.region-worker
  count                       = var.workers-count
  ami                         = data.aws_ssm_parameter.linuxAmiOregon.value
  instance_type               = var.instance-type
  key_name                    = aws_key_pair.worker-key.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.jenkins-sg-oregon.id]
  subnet_id                   = aws_subnet.subnet_1_oregon.id

  tags = {
    Name = join("_", ["jenkins_worker_tf", count.index + 1])
  }
  depends_on = [aws_main_route_table_association.set-worker-default-rt-assoc, aws_instance.jenkins-master]

  provisioner "local-exec" {
    command = <<EOF
    aws --profile ${var.profile} ec2 wait instance-status-ok --region ${var.region-worker} --instance-ids ${self.id}
    ansible-playbook --extra-vars "passed_in_hosts=tag_Name_${self.tags.Name} master_ip=${aws_instance.jenkins-master.private_ip}" ansible_templates/install_jenkins_worker.yml
    EOF
  }
# We are adding this destroy-time provisioner to the Jenkins worker resource is because the workers are going to be ephemeral, as they come and go but the jenkins master is the only constant in this equastion.
# We need the Jenkins worker to deregister itself if it has been deleted

provisioner "remote-exec" {
  when = destroy
  inline = [
    "java -jar /home/ec2-user/jenkins-cli.jar -auth @/home/ec2-user/jenkins_auth -s http://${aws_instance.jenkins-master.private_ip}:8080 delete-node ${self.private_ip}"
  ]
  connection { #To connect and log to the instance in question
    type = "ssh"
    user = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
    host = self.public_ip
  }
}

}
# We need to track de IP addresses so we can SSH into these instances
# This is a way to somehow output those IP addresses 
# The way to do that is using the outputs block


# Output block for showing the public IP address of our Jenkins Master Node
output "Jenkins-Main-Node-Public-IP" {
  value = aws_instance.jenkins-master.public_ip
}

# This output block we are parsing in a map to the value
# In terraform map values are presented by clurly braces
# And lists are represented by square brackets
output "Jenkins-Worker-Public-IPs" {
  value = {
    for instance in aws_instance.jenkins-worker-oregon :
    instance.id => instance.public_ip
  }
}

# Add LB DNS name to Outputs
output "LB-DNS-NAME" {
  value = aws_lb.application-lb.dns_name
}
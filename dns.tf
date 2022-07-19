# Will be using the data source to copy over 
# the details of the publicly configured hosted zone
# DNS configuration
# Get already publicly configured hosted Zone on ROute53 - Must Exist

data "aws_route53_zone" "dns" {
  provider = aws.region-master
  name     = var.dns-name
}

# Create record in hosted zone for ACM certificate Domain verification
# The attribute domain_validation_options is a set of domain validation properties
# And provides us value such as the validation record itself
# Are presented as data type of Set. We can not access data type set by indexes. 
# That's why we use a for loop to generate a list of data that we want to populate in our resource
# The for iterates over the values inside the set (Provided by domain:validation_options)
# The for_each is similar to the count parameter. We use it to dinamically generate nested blocks within a Terraform resource
# Populates it against an object provided by the force_each called each
# To pass the actual values returned to the parameters

resource "aws_route53_record" "cert_validation" {
  provider = aws.region-master
  for_each = {
    for val in aws_acm_certificate.jenkins-lb-https.domain_validation_options : val.domain_name => {
      name   = val.resource_record_name
      record = val.resource_record_value
      type   = val.resource_record_type
    }
  }
  name    = each.value.name
  records = [each.value.record]
  ttl     = 60
  type    = each.value.type
  zone_id = data.aws_route53_zone.dns.zone_id
}

# Create Alias record towards ALB from Route53
resource "aws_route53_record" "jenkins" {
  provider = aws.region-master
  zone_id  = data.aws_route53_zone.dns.zone_id
  name     = join(".", ["jenkins", data.aws_route53_zone.dns.name])
  type     = "A"
  alias {
    name                   = aws_lb.application-lb.dns_name
    zone_id                = aws_lb.application-lb.zone_id
    evaluate_target_health = true
  }
}






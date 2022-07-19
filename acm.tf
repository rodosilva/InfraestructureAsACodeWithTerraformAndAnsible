# ACM Configuration
# Creates ACM certificate and requests validation via DNS(Route53)
# Validating the ownership of this zone which you passing to it using DNS

# Before the Amazon Certificate Authority can Issue a certificate for our site
# AWS certificate Manager must verify that we own or control all of the domain names
# we have specified in our request via de domain_name parameter
# ACM uses CNAME records to validate that we own or control a domain
# When you choose a DNS validation ACM provides a CNAME record to insert into your DNS
# Database so that it can validate the ownership of the domain name

resource "aws_acm_certificate" "jenkins-lb-https" {
  provider          = aws.region-master
  domain_name       = join(".", ["jenkins", data.aws_route53_zone.dns.name])
  validation_method = "DNS"
  tags = {
    "Name" = "Jenkins-ACM"
  }
}

# Validates ACM issued certificate via Route53
# We have to provide the index here wich is provided by each.key
# The each object is again provided by the for_each expression

resource "aws_acm_certificate_validation" "cert" {
  provider                = aws.region-master
  certificate_arn         = aws_acm_certificate.jenkins-lb-https.arn
  for_each                = aws_route53_record.cert_validation
  validation_record_fqdns = [aws_route53_record.cert_validation[each.key].fqdn]
}

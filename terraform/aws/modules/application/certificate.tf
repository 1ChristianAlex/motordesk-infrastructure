resource "aws_acm_certificate" "api" {
  count             = var.api_domain_name == "" ? 0 : 1
  domain_name       = var.api_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "certificate_validation" {
  for_each = var.route53_zone_id == "" || var.api_domain_name == "" ? {} : {
    for option in aws_acm_certificate.api[0].domain_validation_options : option.domain_name => option
  }

  zone_id         = var.route53_zone_id
  name            = each.value.resource_record_name
  type            = each.value.resource_record_type
  records         = [each.value.resource_record_value]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "api" {
  count           = var.api_domain_name == "" ? 0 : 1
  certificate_arn = aws_acm_certificate.api[0].arn
  validation_record_fqdns = var.route53_zone_id == "" ? [] : [
    for record in aws_route53_record.certificate_validation : record.fqdn
  ]
}

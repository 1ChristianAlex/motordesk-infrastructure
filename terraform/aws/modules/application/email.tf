resource "aws_sesv2_email_identity" "sender" {
  email_identity = var.ses_from_address
}

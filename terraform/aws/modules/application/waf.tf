resource "aws_wafv2_web_acl" "api" {
  name        = "${var.project_name}-${var.environment}-api-auth-boundary"
  description = "Allow classified public routes and bearer-protected API routes only."
  scope       = "REGIONAL"

  default_action {
    block {
      custom_response {
        response_code = 401

        response_header {
          name  = "X-MotorDesk-Edge-Auth"
          value = "required"
        }
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-api-auth-boundary"
    sampled_requests_enabled   = false
  }

  lifecycle {
    ignore_changes = [rule]
  }
}

resource "aws_wafv2_web_acl_rule" "options_preflight" {
  web_acl_arn = aws_wafv2_web_acl.api.arn

  name     = "allow-options-preflight"
  priority = 0

  action {
    allow {}
  }

  statement {
    byte_match_statement {
      field_to_match {
        method {}
      }

      positional_constraint = "EXACTLY"
      search_string         = "OPTIONS"

      text_transformation {
        priority = 0
        type     = "NONE"
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-api-options"
    sampled_requests_enabled   = false
  }
}

resource "aws_wafv2_web_acl_rule" "public_routes" {
  web_acl_arn = aws_wafv2_web_acl.api.arn

  name     = "allow-public-routes"
  priority = 1

  action {
    allow {}
  }

  statement {
    or_statement {
      statement {
        and_statement {
          statement {
            byte_match_statement {
              field_to_match {
                method {}
              }

              positional_constraint = "EXACTLY"
              search_string         = "GET"

              text_transformation {
                priority = 0
                type     = "NONE"
              }
            }
          }

          statement {
            regex_match_statement {
              field_to_match {
                uri_path {}
              }

              regex_string = "^(/health|/openapi|/swaggerUI(/.*)?)$"

              text_transformation {
                priority = 0
                type     = "NONE"
              }
            }
          }
        }
      }

      statement {
        and_statement {
          statement {
            byte_match_statement {
              field_to_match {
                method {}
              }

              positional_constraint = "EXACTLY"
              search_string         = "POST"

              text_transformation {
                priority = 0
                type     = "NONE"
              }
            }
          }

          statement {
            regex_match_statement {
              field_to_match {
                uri_path {}
              }

              regex_string = "^/(login|register/client)$"

              text_transformation {
                priority = 0
                type     = "NONE"
              }
            }
          }
        }
      }

      statement {
        and_statement {
          statement {
            byte_match_statement {
              field_to_match {
                method {}
              }

              positional_constraint = "EXACTLY"
              search_string         = "GET"

              text_transformation {
                priority = 0
                type     = "NONE"
              }
            }
          }

          statement {
            regex_match_statement {
              field_to_match {
                uri_path {}
              }

              regex_string = "^/service-order/client/[^/]+/approval$"

              text_transformation {
                priority = 0
                type     = "NONE"
              }
            }
          }
        }
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-api-public"
    sampled_requests_enabled   = false
  }
}

resource "aws_wafv2_web_acl_rule" "protected_routes_with_bearer" {
  web_acl_arn = aws_wafv2_web_acl.api.arn

  name     = "allow-protected-routes-with-bearer"
  priority = 2

  action {
    allow {}
  }

  statement {
    and_statement {
      statement {
        byte_match_statement {
          field_to_match {
            single_header {
              name = "authorization"
            }
          }

          positional_constraint = "STARTS_WITH"
          search_string         = "bearer "

          text_transformation {
            priority = 0
            type     = "LOWERCASE"
          }
        }
      }

      statement {
        or_statement {
          statement {
            and_statement {
              statement {
                byte_match_statement {
                  field_to_match {
                    method {}
                  }

                  positional_constraint = "EXACTLY"
                  search_string         = "GET"

                  text_transformation {
                    priority = 0
                    type     = "NONE"
                  }
                }
              }

              statement {
                regex_match_statement {
                  field_to_match {
                    uri_path {}
                  }

                  regex_string = "^/(service-order/manager/(list|[^/]+)|service-order/client(/[^/]+)?|self|vehicles/owner)$"

                  text_transformation {
                    priority = 0
                    type     = "NONE"
                  }
                }
              }
            }
          }

          statement {
            and_statement {
              statement {
                byte_match_statement {
                  field_to_match {
                    method {}
                  }

                  positional_constraint = "EXACTLY"
                  search_string         = "POST"

                  text_transformation {
                    priority = 0
                    type     = "NONE"
                  }
                }
              }

              statement {
                regex_match_statement {
                  field_to_match {
                    uri_path {}
                  }

                  regex_string = "^/(register/manager|service-order/manager/create|vehicles/create)$"

                  text_transformation {
                    priority = 0
                    type     = "NONE"
                  }
                }
              }
            }
          }

          statement {
            and_statement {
              statement {
                byte_match_statement {
                  field_to_match {
                    method {}
                  }

                  positional_constraint = "EXACTLY"
                  search_string         = "PUT"

                  text_transformation {
                    priority = 0
                    type     = "NONE"
                  }
                }
              }

              statement {
                regex_match_statement {
                  field_to_match {
                    uri_path {}
                  }

                  regex_string = "^/(service-order/manager/update|vehicles/update|self/update)$"

                  text_transformation {
                    priority = 0
                    type     = "NONE"
                  }
                }
              }
            }
          }

          statement {
            and_statement {
              statement {
                byte_match_statement {
                  field_to_match {
                    method {}
                  }

                  positional_constraint = "EXACTLY"
                  search_string         = "DELETE"

                  text_transformation {
                    priority = 0
                    type     = "NONE"
                  }
                }
              }

              statement {
                regex_match_statement {
                  field_to_match {
                    uri_path {}
                  }

                  regex_string = "^/(service-order/manager/[^/]+/delete|vehicles/delete/[^/]+)$"

                  text_transformation {
                    priority = 0
                    type     = "NONE"
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-api-protected"
    sampled_requests_enabled   = false
  }
}

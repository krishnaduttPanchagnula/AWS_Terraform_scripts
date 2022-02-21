terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-south-1"
}

resource "aws_cloudwatch_event_rule" "eventtosns" {
  name = "lambdaless"
  event_pattern = jsonencode(
    {
      account = [
        var.region,
      ]
    }
  )



}


resource "aws_cloudwatch_event_target" "eventtosns" {


  # arn of the target and rule id of the eventrule
  arn  = aws_sns_topic.eventtosns.arn
  rule = aws_cloudwatch_event_rule.eventtosns.id

  input_transformer {
    input_paths = {
      Source      = "$.source",
      detail-type = "$.detail-type",
      resources   = "$.resources",
      state       = "$.detail.state",
      status      = "$.detail.status"
    }
    input_template = "\"Resource name : <Source> , Action name : <detail-type>,  details : <status> <state>, Arn : <resources>\""
  }
}




resource "aws_sns_topic" "eventtosns" {
  name = "eventtosns"
}


resource "aws_sns_topic_subscription" "snstoemail_email-target" {
  topic_arn = aws_sns_topic.eventtosns.arn
  protocol  = "email"
  endpoint  = var.email
}


# aws_sns_topic_policy.eventtosns:
resource "aws_sns_topic_policy" "eventtosns" {
  arn = aws_sns_topic.eventtosns.arn

  policy = jsonencode(
    {
      Id = "__default_policy_ID"
      Statement = [
        {
          Action = [
            "SNS:GetTopicAttributes",
            "SNS:SetTopicAttributes",
            "SNS:AddPermission",
            "SNS:RemovePermission",
            "SNS:DeleteTopic",
            "SNS:Subscribe",
            "SNS:ListSubscriptionsByTopic",
            "SNS:Publish",
          ]

          condition = {
            test     = "StringEquals"
            variable = "AWS:SourceOwner"
            values = [
              "498830417177",
            ]
          }



          Effect = "Allow"
          Principal = {
            AWS = "*"
          }
          Resource = aws_sns_topic.eventtosns.arn
          Sid      = "__default_statement_ID"
        },
        {
          Action = "sns:Publish"
          Effect = "Allow"
          Principal = {
            Service = "events.amazonaws.com"
          }
          Resource = aws_sns_topic.eventtosns.arn
          Sid      = "AWSEvents_lambdaless_Idcb618e86-b782-4e67-b507-8d10aaca5f09"
        },
      ]
      Version = "2008-10-17"
    }
  )
}

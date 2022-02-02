terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider region
provider "aws" {
  region = var.region
}

# step function - failed or other problems - monitoring code
resource "aws_cloudwatch_event_rule" "console" {
  name = "captureawsactivity"


  event_pattern = <<EOF
{
  "source": ["aws.states"],
  "detail-type": ["Step Functions Execution Status Change"],
  "detail": {
    "status": ["FAILED", "TIMED_OUT", "ABORTED"] } 
}


EOF
}


#AWS cloudwatch event rule
resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.console.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.aws_activity.arn
}

#lambda policy creation function
resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}



#lambda monitoring code
resource "aws_lambda_function_event_invoke_config" "example" {

  function_name = "arn:aws:lambda:ap-south-1:498830417177:function:AAA"

  destination_config {
    
    # on_failure {
    #   destination = aws_sns_topic.aws_activity.arn
    # }

    on_success {
      destination = aws_sns_topic.aws_activity.arn
    }


  }
}
#  """hook the path of the python zip here to the one preset in the below code"""
# locals {
#   lambda_zip_location = "lambdas\s3_upload.zip"
# }


# """Work needed to make sure the lambda works and shows errors when there is a problem"""
#lambda creation function
# resource "aws_lambda_function" "test_lambda" {
#   filename      = "lambda_function_payload.zip"
#   function_name = "lambda_function_name"
#   role          = aws_iam_role.iam_for_lambda.arn
#   handler       = "index.test"

 
#   runtime = "python3.8"

#   environment {
#     variables = {
#       foo = "bar"
#     }
#   }
# }



# SNS topic creation
resource "aws_sns_topic" "aws_activity" {
  name = "aws-console-activity"
}

# SNS topic subscription

resource "aws_sns_topic_subscription" "email-target" {
  topic_arn = aws_sns_topic.aws_activity.arn
  protocol  = "email"
  endpoint  = var.email
}

#SNS topic policy
resource "aws_sns_topic_policy" "default" {
  arn    = aws_sns_topic.aws_activity.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}


#SNS IAM policy
data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    effect = "Allow"
    actions = [
      "SNS:Subscribe",
      "SNS:SetTopicAttributes",
      "SNS:RemovePermission",
      "SNS:Receive",
      "SNS:Publish",
      "SNS:ListSubscriptionsByTopic",
      "SNS:GetTopicAttributes",
      "SNS:DeleteTopic",
      "SNS:AddPermission",
    ]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [aws_sns_topic.aws_activity.arn]
  }
}
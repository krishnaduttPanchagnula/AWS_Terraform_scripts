# AWS N TERRAFORM ARCHITECTURE
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



# EVENTBRIDGE ARCHITECTURE
resource "aws_cloudwatch_event_rule" "alleventmonitor" {

  name = "alleventmonitor"
  
  event_pattern = <<EOF
  {
  "account": ["498830417177"]
  }
EOF
}
    


resource "aws_cloudwatch_event_target" "eventpushtolambda" {

  arn  = aws_lambda_function.alleventmonitoring_lambda.arn
  rule = aws_cloudwatch_event_rule.alleventmonitor.name

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





# SNS ARCHITECTURE

resource "aws_sns_topic" "alleventsns" {
  name = "alleventsns"
}


resource "aws_sns_topic_subscription" "snstoemail_email-target" {
  topic_arn = aws_sns_topic.alleventsns.arn
  protocol  = "email"
  endpoint  = var.email
}


# aws_sns_topic_policy.eventtosns:
resource "aws_sns_topic_policy" "default" {
  arn = aws_sns_topic.alleventsns.arn

  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  policy_id = "__default_policy_ID"

  statement {
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

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"

      values = [
        var.account,
      ]
    }

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_sns_topic.alleventsns.arn,
    ]

    sid = "__default_statement_ID"
  }
}


# LAMBDA ARCHITECTURE

# aws_iam_role.iam_for_alleventmonitoring:
resource "aws_iam_role" "iam_for_alleventmonitoring" {

  name = "iam_for_alleventmonitoring"

  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "lambda.amazonaws.com"
          }
        },
      ]
      Version = "2012-10-17"
    }
  )

  managed_policy_arns   = [aws_iam_policy.AWSLambdaBasicExecutionRole.arn, aws_iam_policy.AWSLambdaSNSPublishPolicyExecutionRole.arn,aws_iam_policy.AWSLambdaSNSTopicDestinationExecutionRole.arn]

  inline_policy {}
}

resource "aws_iam_policy" "AWSLambdaBasicExecutionRole" {
  name = "AWSLambdaBasicExecutionRole-alleventmonitoring_lambda"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
})
}

resource "aws_iam_policy" "AWSLambdaSNSPublishPolicyExecutionRole" {
  name = "AWSLambdaSNSPublishPolicyExecutionRole-alleventmonitoring_lambda"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sns:Publish"
            ],
            "Resource": "arn:aws:sns:*:*:*"
        }
    ]
})
}

resource "aws_iam_policy" "AWSLambdaSNSTopicDestinationExecutionRole" {
  name = "AWSLambdaSNSTopicDestinationExecutionRole-alleventmonitoring_lambda"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sns:Publish",
            "Resource": aws_sns_topic.alleventsns.arn
        }
    ]
})
}


data "archive_file" "Resource_monitoring_lambdascript" {
  type        = "zip"
  source_file = "lambda_script/lambda_function.py"
  output_path = "lambda_zipped/lambda_function.zip"
}


# aws_lambda_function.alleventmonitoring_lambda:
resource "aws_lambda_function" "alleventmonitoring_lambda" {
  function_name = "alleventmonitoring_lambda"
  handler       = "lambda_function.lambda_handler"
  package_type  = "Zip"
  filename      = data.archive_file.Resource_monitoring_lambdascript.output_path

  role             = aws_iam_role.iam_for_alleventmonitoring.arn
  runtime          = "python3.9"
  source_code_hash = data.archive_file.Resource_monitoring_lambdascript.output_base64sha256

  timeouts {}

  tracing_config {
    mode = "PassThrough"
  }
}
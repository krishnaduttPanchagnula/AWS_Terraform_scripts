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
  region = "ap-south-1"
}

 # step and lambda function - failed or other problems
resource "aws_cloudwatch_event_rule" "console" {
  name        = "captureawsactivity"
  

  event_pattern = <<EOF
{
  "source": ["aws.states"],
  "detail-type": ["Step Functions Execution Status Change"],
  "detail": {
    "status": ["FAILED", "TIMED_OUT", "ABORTED"] } 
}


EOF
}

resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.console.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.aws_activity.arn
}

# Below is fine
resource "aws_sns_topic" "aws_activity" {
  name = "aws-console-activity"
}

resource "aws_sns_topic_subscription" "email-target" {
  topic_arn = aws_sns_topic.aws_activity.arn
  protocol  = "email"
  endpoint  = "johnaws1209@gmail.com"
}

resource "aws_sns_topic_policy" "default" {
  arn    = "${aws_sns_topic.aws_activity.arn}"
  policy = "${data.aws_iam_policy_document.sns_topic_policy.json}"
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    effect  = "Allow"
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
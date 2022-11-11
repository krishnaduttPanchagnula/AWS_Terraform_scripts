data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

//CLOUDTRAIL
resource "aws_cloudtrail" "aws_sg_monitoring" {
  name                          = var.cloudtrailname
  s3_bucket_name                = aws_s3_bucket.cloudtraillogs.id
  s3_key_prefix                 = "prefix"
  include_global_service_events = false
}

resource "aws_s3_bucket" "cloudtraillogs" {
  bucket        = var.trailbucketname
  force_destroy = true
}

resource "aws_s3_bucket_policy" "aws_sg" {
  bucket = aws_s3_bucket.cloudtraillogs.id
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSCloudTrailAclCheck",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "${aws_s3_bucket.cloudtraillogs.arn}"
        },
        {
            "Sid": "AWSCloudTrailWrite",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "${aws_s3_bucket.cloudtraillogs.arn}/prefix/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        }
    ]
}
POLICY
}

//EVENTBRIDGE

resource "aws_cloudwatch_event_rule" "aws_sg" {
  name        = var.cloudwatch_event_rule_name
  description = "Captures Changes in Security group and remediates it by sending it to lambda "

  event_pattern = <<EOF
{
  "source": ["aws.ec2"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventSource": ["ec2.amazonaws.com"]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "example" {
  target_id = "SendtoLambda"
  arn       = aws_lambda_function.aws_sg.arn // ARN OF LAMBDA
  rule      = aws_cloudwatch_event_rule.aws_sg.id
}




// SNS 
resource "aws_sns_topic" "aws_sg_sns" {
  name   = var.snstopicname
  policy = <<EOT
{
  "Version": "2008-10-17",
  "Id": "__default_policy_ID",
  "Statement": [
    {
      "Sid": "__default_statement_ID",
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": [
        "SNS:GetTopicAttributes",
        "SNS:SetTopicAttributes",
        "SNS:AddPermission",
        "SNS:RemovePermission",
        "SNS:DeleteTopic",
        "SNS:Subscribe",
        "SNS:ListSubscriptionsByTopic",
        "SNS:Publish"
      ],
      "Resource": "${aws_sns_topic.aws_sg_sns.arn}",
      "Condition": {
        "StringEquals": {
          "AWS:SourceOwner": "${data.aws_caller_identity.current.account_id}"
        }
      }
    },
    {
      "Sid": "AWSEvents_aws_SG",
      "Effect": "Allow",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Action": "sns:Publish",
      "Resource": "${aws_sns_topic.aws_sg_sns.arn}"
    }
  ]
}
EOT
}

resource "aws_sns_topic_subscription" "sg_emailsubscription" {
  topic_arn = aws_sns_topic.aws_sg_sns
  protocol  = "email"
  endpoint  = var.email
}

//LAMBDA


## Lambda and Logging 

resource "aws_cloudwatch_log_group" "aws_sg_log" {
  name              = "/aws/lambda/${aws_lambda_function.aws_sg.function_name}"
  retention_in_days = 0
}

data "archive_file" "SG_monitoring_lambdascript" {
  type        = "zip"
  source_file = "./lambda_function.py"
  output_path = "./lambda_function.zip"
}

resource "aws_lambda_function" "aws_sg" {
  function_name    = "aws_sg"
  filename         = data.archive_file.SG_monitoring_lambdascript.output_path
  handler          = "lambda_function.lambda_handler"
  package_type     = "Zip"
  role             = aws_iam_role.aws_sg-role.arn
  runtime          = "python3.9"
  source_code_hash = filebase64sha256(data.archive_file.SG_monitoring_lambdascript.output_path)
  tracing_config {
    mode = "PassThrough"
  }



  environment {
    variables = {
      snsarn = "${aws_sns_topic.aws_sg_sns.arn}"
    }
  }
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.aws_sg.function_name
  principal     = "logs.${data.aws_region.current.name}.amazonaws.com"
  source_arn    = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"

}

#IAM role and policies

resource "aws_iam_role" "aws_sg-role" {
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
POLICY

  managed_policy_arns = [aws_iam_policy.LambdaExecutionRole.arn, aws_iam_policy.AmazonEC2FullAccess.arn]

  name = "aws_sg-role"
  path = "/service-role/"

  tags = {
    sg = "true"
  }

  tags_all = {
    sg = "true"
  }
}


# aws_iam_policy.LambdaExecutionRole:
resource "aws_iam_policy" "LambdaExecutionRole" {

  name = "AWSLambdaBasicExecutionRole_for_SG"
  path = "/service-role/"
  policy = jsonencode(
    {
      Statement = [
        {
          Action   = "logs:CreateLogGroup"
          Effect   = "Allow"
          Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
        },
        {
          Action = [
            "logs:CreateLogStream",
            "logs:PutLogEvents",
          ]
          Effect = "Allow"
          Resource = [
            aws_cloudwatch_log_group.aws_sg_log.arn, // logs arn
          ]
        },
      ]
      Version = "2012-10-17"
    }
  )

}

# aws_iam_policy.AmazonEC2FullAccess:
resource "aws_iam_policy" "AmazonEC2FullAccess" {

  description = "Provides full access to Amazon EC2 via the AWS Management Console."

  name = "AmazonEC2FullAccess"
  path = "/"
  policy = jsonencode(
    {
      Statement = [
        {
          Action   = "ec2:*"
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action   = "elasticloadbalancing:*"
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action   = "cloudwatch:*"
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action   = "autoscaling:*"
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = "iam:CreateServiceLinkedRole"
          Condition = {
            StringEquals = {
              "iam:AWSServiceName" = [
                "autoscaling.amazonaws.com",
                "ec2scheduled.amazonaws.com",
                "elasticloadbalancing.amazonaws.com",
                "spot.amazonaws.com",
                "spotfleet.amazonaws.com",
                "transitgateway.amazonaws.com",
              ]
            }
          }
          Effect   = "Allow"
          Resource = "*"
        },
      ]
      Version = "2012-10-17"
    }
  )

}


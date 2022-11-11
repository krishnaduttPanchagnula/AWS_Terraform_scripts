variable "trailbucketname" {
  description = "Name of the bucket to save cloudtrail logs"
  default     = "cloudtrail-logs"

}

variable "cloudtrailname" {
  default     = "Security_group"
  description = "Name for the cloud trail"

}

variable "lambda_arn" {
  description = "The value of arn to send the notification to"

}

variable "cloudwatch_event_rule_name" {
  description = "Name for the eventbridge rule"

}

variable "snstopicname" {
  description = "Name for the sns topic to send sg alerts"
  default     = "SG_sns"
}

variable "email" {
  description = "Email to send the alerts of Security group drift"
  default     = "krishnadutt123@gmail.com"
}
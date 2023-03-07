variable "trailbucketname" {
  description = "Name of the bucket to save cloudtrail logs"
  default     = "cloudtrail-logs-sg-test-498830417177-742e5a6b"

}

variable "cloudtrailname" {
  default     = "Security_group_test_logs_test-498830417177-742e5a6b"
  description = "Name for the cloud trail"

}


variable "cloudwatch_event_rule_name" {
  description = "Name for the eventbridge rule"
  default = "cloudwatch_sg_test"

}

variable "snstopicname" {
  description = "Name for the sns topic to send sg alerts"
  default     = "SG_sns"
}

variable "email" {
  description = "Email to send the alerts of Security group drift"
  default     = "krishnadutt123@gmail.com"
}
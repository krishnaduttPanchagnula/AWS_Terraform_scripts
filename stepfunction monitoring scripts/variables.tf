variable "region" {
  description = "The desired region to set up the infrastructure"
  type        = string
  default     = "ap-south-1"

}

variable "email" {
  description = "list of emails to send the notification to"
  type        = string
  default     = "johnaws1209@gmail.com"

}


variable "region" {
  description = "The id of the region"
  type        = string

  default = "Your-region-id"
}

variable "email" {
  description = "Email to send sns notification"
  type        = string
  default     = "youremail@yourdomain.com"

}
variable "account" {
  description = "account name"
  type        = string
  default     = "your-account-number"
}

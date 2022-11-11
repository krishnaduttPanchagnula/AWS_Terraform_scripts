# Terraform repository

### This repository contains list of all scripts i have developed for developing, maintaining and monitoring the AWS infrastructure using Terraform (Infrastructure as Code).

This repository contains a list of solutions for different problems in the AWS cloud using Terraform. 

| Problem      | Solution  | Link to Solution |
|--------------|-----------|------------|
|Security Groups are sometimes misconfigured by the engineers from our baseline ( set usually by security architect) and this causes active toll on Cloud team to constantly monitor each SG and make changes whenever necessary | This tool checks each of the security group with the baseline configuration defined by SG and if there is a violation, the rogue configuration is **eliminated** and Email to sent to cloud engineering team regarding the situation |[Link](https://github.com/krishnaduttPanchagnula/AWS_Terraform_scripts/tree/master/Auto%20Delete%20insecure%20securitygroup%20ingress%20rules) |
| Instead of sending entire log of event, the end user wanted only details such as Resource Name, ARN and action | We used Cloudwatch input transformer ( instead of a seperate lambda fu nction) to parse the logs and send email to the user using SNS | [Link](https://github.com/krishnaduttPanchagnula/AWS_Terraform_scripts/tree/master/eventbridge_sns)        |
| To Monitor each every event of the EC2 and S3 ( both State changes and data changes)      | This terraform script monitors the AWS S3 and ec2 activity and sends a email notification whenever there is a stage/data change in S3 buckets or ec2 instances  | [Link](https://github.com/krishnaduttPanchagnula/AWS_Terraform_scripts/tree/master/s3_ec2_monitoring%20scripts)       |
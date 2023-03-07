# Auto Delete insecure securitygroup ingress rules

As a Dev-ops engineer, we use different compute resources in our cloud,  to make sure that  different workloads are working efficiently. And in order to restrict the traffic accessing our compute resources ( EC2/ECS/EKS instance in case of AWS) , we create stateful firewalls ( like Security groups in AWS). And as a lead engineer, we often describe the best practices for configuring the Security groups.But when we have large organization working on cloud, monitoring and ensuring each team follows these best practices is quite a tedious task and often eats up lot of productive hours. And it is not as if we can ignore this, this causes security compliance issues. 

For example, the Security group might be configured with following configuration by a new developer ( or some rogue engineer). If we observe the below , security group which is supposed to restrict the traffic to different AWS resources is configured to allow all kinds of traffic on all protocols from the entire internet. This beats the logic of configuring the securing the resource with security group and might as well remove it.  

```json
{
    "version": "0",
    "detail-type": "AWS API Call via CloudTrail",
      "responseElements": {
        "securityGroupRuleSet": {
          "items": [
            {
              "groupOwnerId": "XXXXXXXXXXXXX",
              "groupId": "sg-0d5808ef8c4eh8bf5a",
              "securityGroupRuleId": "sgr-035hm856ly1e097d5",
              "isEgress": false,
              "ipProtocol": "-1",  --> It allows traffic from all protocols
              "fromPort": -1, --> to all the ports
              "toPort": -1,
              "cidrIpv4": "0.0.0.0/0" --> from entire internet, which is a bad practice.
            }
          ]
        }
      },
    }
  }
```

This kind of mistake can be done while building a Proof Of Concept or While testing a feature, which would cost us lot in terms of security. And Monitoring these kind of things by Cloud Engineers takes a toll and consumes a lot of time.What if we can automate this monitoring and create a self-healing mechanism, which would detect the deviations from best practices and remediate them? 

## System’s Architecture and Working:

The present solution that i have built in AWS, watches the each Security group ingress rule ( can be extended to even engress rules too) the ports that it is allowing, the protocol its using and the IP range that it communicating with. These security group rules are compared with the baseline rules that we define for our security compliance, and any deviations are automatically removed. These baserules are configured in the python code( which can be modified to our liking, based on the requirement).


### Components used to build this system

1. AWS Cloud trail
2. AWS event bridge rule
3. AWS lambda 
4. AWS SNS

### Application Flow 

1. Whenever a new activity ( either creation/modification/deletion of rule) is performed in the security group, its event log not sent as event log to cloud watch ,but as api call to cloud trail. So to monitor these events, we need to first enable cloud trail. This cloud trail will monitor all the api cloud trails from EC2 source and save them in a log file in S3 bucket.

```go
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
```

1. Once these api calls are being recorded, we need to filter only those which are related to the Security group api calls. This can be done by directly sending all the api call to another lambda or via AWS event bridge rule. The former solution using lambda is costly as each api call will invoke lambda, so we create a event bridge rule to only cater the api calls from ec2 instance.

```go
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
```

1. These filtered api events are sent to the lambda, which will check for the port, protocol and traffic we have previously configured in the python code( In this example, i am checking for wildcard IP - which is entire internet, all the ports on ingress rule. You can also filter with with the protocol that you dont want to allow. Refer the code for details)

```python
import os
import boto3

def lambda_handler(event, context):
    print("Checking if the created NetworkACL has an insecure ingress ACL entry: 0.0.0.0/0, rule action: allow, port range -1 and Ingress ACL entry")


    try:

        cidr_block = event['detail']['requestParameters']['ipPermissions']['items'][0]['ipRanges']['items'][0]['cidrIp']
        
        is_engress = event['detail']['responseElements']['securityGroupRuleSet']["items"][0]['isEgress']
        from_port = event['detail']['responseElements']['securityGroupRuleSet']["items"][0]['fromPort']
        to_port = event['detail']['responseElements']['securityGroupRuleSet']["items"][0]['toPort']
        
        #! if you want to filter with protocol use this argument in the below if statement.
        # protocol   = event['detail']['responseElements']['securityGroupRuleSet']["items"][0]['ipProtocol']


        if (cidr_block == "0.0.0.0/0" and is_engress == False and (from_port == -1 or (from_port == 0 and to_port == 65535))):
            

            #Getting NetworkACL ID from the event.
            iam = event['detail']['userIdentity']['arn']
            sg_group_id = event['detail']['requestParameters']['groupId']

            
            #getting Rule number to be deleted.
            RuleNumberACLEntry = event['detail']['responseElements']['securityGroupRuleSet']["items"][0]['securityGroupRuleId']
            #Deleting the insecure Ingress Network ACL entry.
            client = boto3.client('ec2')        
            response = client.revoke_security_group_ingress(GroupId=sg_group_id,IpPermissions=[
                {
                    'IpProtocol': '-1',
                    'ToPort': -1,
                    'IpRanges': [{'CidrIp': cidr_block}]
                }
            ])
            
            print(response)

            y= """The Security group of id {sg_name} has a new 
            secrurity rule of id {sg_rule_name} is 
            created by Iam role of {iam_role} and 
            has been deleted""".format(sg_name=sg_group_id,sg_rule_name=RuleNumberACLEntry,iam_role=iam)

            print(y)


            #If you want to send an email to the end user, create a sns before hand via terraform 
            #and pass it as env variables to the lambda function
            sns = boto3.client('sns')
            sns.publish(TopicArn= os.environ['SNSARN'],Message=y,Subject='Insecure Ingress ACL entry')
    except KeyError as e:
        print("This SG passes the Lambda Security Group Filter")
    
    

   

```

1. The python code will filter all the security groups and find the security group rules, which violate them and delete them. 
2. Once these are deleted, SNS is used to send email event details such as arn of security group rule, the **role arn of the person** creating this rule, the violations that the rule group has done in reference to baseline security compliance. This email altering can help us to understand the actors causing these deviations and give proper training on the security compliance.

```python
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
```

To replicate this system in your environment, change the base security rules that you want to monitor for in python and type *terraform apply* in the terminal. Sit back and have a cup of coffee, while the terraform builds this system in your AWS account.

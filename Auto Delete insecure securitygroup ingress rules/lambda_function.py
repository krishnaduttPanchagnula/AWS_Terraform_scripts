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
    except Exception as e:
        print(e)
    
    

   

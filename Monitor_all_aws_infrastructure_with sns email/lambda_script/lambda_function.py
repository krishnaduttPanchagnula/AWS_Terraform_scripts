import json
import re
import boto3

def lambda_handler(event, context):
    clause_lo = ["pending","failed","cancelled","deleted","stopping","shutting-down","stopped","stopped","terminate","terminated"]
    clause_up = [i.upper() for i in clause_lo]
    clause_cap = [i.capitalize() for i in clause_lo]
    clause_to = clause_lo + clause_up +clause_cap
    

    
    sns = boto3.client('sns')
    print(event)
    print(sns)
    
    
    for i in clause_to:
        
        if re.search(i, str(event)):
            response = sns.publish(TopicArn='arn:aws:sns:ap-south-1:498830417177:final',Message = event)
            print(response)
        else:
            print("Nothing to look here")
    

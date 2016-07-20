#### Request certificate:


```
aws acm request-certificate --domain-name *.<your-domain> --subject-alternative-names *.system.<your-domain> *.login.system.<your-domain> *.uaa.system.<your-domain> *.apps<your-domain> --domain-validation-options DomainName=*.<your-domain>,ValidationDomain=<domain>
```
Example:

```
aws acm request-certificate --domain-name *.tsaws.cf-app.com --subject-alternative-names *.system.tsaws.cf-app.com *.login.system.tsaws.cf-app.com *.uaa.system.tsaws.cf-app.com *.apps.tsaws.cf-app.com --domain-validation-options DomainName=*.tsaws.cf-app.com,ValidationDomain=cf-app.com
```
#### Create key-pair

```
aws ec2 create-key-pair --key-name <you-NATKey-name> | jq -r ".KeyMaterial" > <your-NATPrivateKey>
```

#### Create key-pair.json file to pass parameters

```
[
  {
   "ParameterKey":"05RdsUsername",
   "ParameterValue": "your-username"
  },
  {
    "ParameterKey": "06RdsPassword",
    "ParameterValue": "your-password"
  },
  {
    "ParameterKey": "01NATKeyPair",
    "ParameterValue": "your-NATKey-name"
  },
  {
     "ParameterKey":"07SSLCertificateARN",
     "ParameterValue": "your-arn"
  }
]
```

#### Execute cloudformation script

```
aws cloudformation create-stack --stack-name toolsmiths-aws --template-body file:////Users//pivotal//workspace//tmp//pcf_1_7_cloudformation.json --parameters file:////Users//pivotal//workspace//tmp//keyvaluePair.json --capabilities CAPABILITY_IAM
```
Output:

```
{
    "StackId": "arn:aws:cloudformation:us-east-1:504478669291:stack/toolsmiths-aws/your-fomration-id"
}
```

**NOTE:** this step will take time (get coffee or catch pokemon in the mean time)

# Título do Projeto

Registrar conteúdo de aprendizagem sobre AWS Lambda

## 0. Requisitos
- AWS Cli ([link sobre instalação](https://docs.aws.amazon.com/pt_br/cli/latest/userguide/getting-started-install.html))
- AWS Sam ([link sobre instalação](https://docs.aws.amazon.com/pt_br/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html))

## 1. Criar projeto local

Crie um projeto local com os comandos abaixo no terminal:


```bash
mkdir lambda && cd lambda && touch app.py template.yaml
mkdir events && touch events/events.json
```
## 2. Teste Layer Local no template
```bash
mkdir lambda_layer
tee -a lambda_layer/requirements.txt <<EOF
pillow == 9.0.1
boto3 == 1.21.23
EOF

echo -e "build-LambdaLayer:" > lambda_layer/Makefile
echo -e "\tmkdir -p \"\${ARTIFACTS_DIR}/python\"" >> lambda_layer/Makefile
echo -e "\tdocker run --user 1000:1000 -v \"$PWD\":/var/task \"lambci/lambda:build-python3.7\" /bin/sh -c \"pip install -r lambda_layer/requirements.txt -t .aws-sam/build/LambdaLayer/python; exit\"" >> lambda_layer/Makefile
```
## 3. Aplicação e template

```bash
tee -a app.py <<EOF
import json
import subprocess
from PIL import Image

def lambda_handler(event, context):
    first_name = event['first_name']
    last_name = event['last_name']

    message = f"Hello {first_name} {last_name}!"  

    print(subprocess.run(["pip --version"], shell=True, check=True, capture_output=True, text=True).stdout)
    print(subprocess.run(["pip list"], shell=True, check=True, capture_output=True, text=True).stdout)
    print(subprocess.run(["cat /etc/system-release"], shell=True, check=True, capture_output=True, text=True).stdout)

    return { 
        'message' : message
    }
EOF
```

```bash
tee -a template.yaml <<EOF
AWSTemplateFormatVersion : '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Resources:
  LambdaLayer:
    Type: AWS::Serverless::LayerVersion
    Properties:
      LayerName: lambda_layer
      ContentUri: lambda_layer
      CompatibleRuntimes:
        - python3.7
    Metadata:
      BuildMethod: makefile
  HelloNameFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: app.lambda_handler
      Runtime: python3.7
      Timeout: 60
      Policies:
        S3ReadPolicy:
          BucketName: bucket-receive-images
      Layers:
        - !Ref LambdaLayer
      Events:
        FileUpload:
          Type: S3
          Properties: 
            Bucket: !Ref HelloLocalBucket
            Events: s3:ObjectCreated:*
  MediaBucketS3Policy:
    Type: 'AWS::S3::BucketPolicy'
    Properties:
      Bucket: !Ref HelloLocalBucket
      PolicyDocument:
        Statement:
          - Action:
              - 's3:*'
            Effect: 'Allow'
            Resource: !Sub 'arn:aws:s3:::${HelloLocalBucket}/*'
            Principal: '*'
  LambdaInvokePermission:
    Type: 'AWS::Lambda::Permission'
    Properties:
      FunctionName: !GetAtt HelloNameFunction.Arn
      Action: 'lambda:InvokeFunction'
      Principal: 's3.amazonaws.com'
      SourceAccount: !Ref 'AWS::AccountId'
      SourceArn: !GetAtt HelloLocalBucket.Arn
  HelloLocalBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: bucket-receive-images
EOF
```
```bash
tee -a events/events.json <<EOF
{
    "first_name": "Carlos",
    "last_name": "Santos"
}
EOF
```
```bash
curl -L 'https://images.pexels.com/photos/9754913/pexels-photo-9754913.jpeg?cs=srgb&dl=pexels-jonathan-cooper-9754913.jpg&fm=jpg&w=13440' -o base.jpg
```
## 4. Deploy AWS

```bash
clear && sam build && sam local invoke HelloNameFunction -e events/events.json
sam deploy --guided
```
- Stack name: HelloNameFunction
- Region: us-east-1
- Confirm changes before deploy ? Deseja ver e aprovar as alterações antes do deploy? Default
- Allow SAM CLI IAM role creation. Default.
- Save arguments (the ones you just made) to configuration file. Default.
- Name of configuration file. Default
- SAM configuration environment. Default.
- Confirm the proposed changeset and watch as your resources are deployed.

## Referência

 - [Developing AWS Lambda Functions Locally With VSCode](https://travis.media/developing-aws-lambda-functions-locally-vscode/)
 - [Launch and Manage EC2 Instances Using AWS CLI](https://medium.com/swlh/launch-and-manage-ec2-instances-using-aws-cli-7efae00e264b)
 - [Python 3.7 plus Pillow in Lambda not working](https://forums.aws.amazon.com/thread.jspa?threadID=309588)
 - [Building Custom Layers on AWS Lambda](https://towardsdatascience.com/building-custom-layers-on-aws-lambda-35d17bd9abbb)
 - [Resize an image using Amazon S3 and Lambda](https://austinlasseter.medium.com/resize-an-image-using-aws-s3-and-lambda-fda7a6abc61c)

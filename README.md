
# Título do Projeto

Registrar conteúdo de aprendizagem sobre AWS Lambda

## 0. Requisitos
- AWS Cli ([link sobre instalação](https://docs.aws.amazon.com/pt_br/cli/latest/userguide/getting-started-install.html))
- AWS Sam ([link sobre instalação](https://docs.aws.amazon.com/pt_br/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html))

## 1. Criar projeto local

Crie um projeto local com os comandos abaixo no terminal:


```bash
$ mkdir lambda && cd lambda && touch app.py template.yaml
$ mkdir events && touch events/events.json
```

## 2. Configurar instancia EC2 (para preparar as dependencias das Lambda Layers)
### 2.1 subir instancia EC2 micro
- [AWS Doc](https://docs.aws.amazon.com/pt_br/cli/latest/userguide/cli-services-ec2-instances.html)

```bash
$ aws ec2 create-key-pair --key-name MyKeyPair --query 'KeyMaterial' --output text > ~/.aws/MyKeyPair.pem
$ chmod 400 MyKeyPair.pem
$ aws ec2 create-security-group --group-name sgEc2Lambda --description "Security group EC2 Lambda"
$ aws ec2 run-instances --instance-type t2.micro --key-name MyKeyPair
$ SECURITYGROUPID=$(aws ec2 describe-security-groups --group-name sgEc2Lambda --query "SecurityGroups[*].{Name:GroupId}" --output text)
$ aws ec2 authorize-security-group-ingress --group-name sgEc2Lambda --protocol tcp --port 22 --cidr 0.0.0.0/0
$ aws ec2 run-instances --image-id ami-0c02fb55956c7d316 --security-group-ids $SECURITYGROUPID --instance-type t2.micro --key-name AwsKeyPair
$ EC2IP=$(aws ec2 describe-instances --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
```
### 2.2 conectado na EC2 micro
```bash
$ ssh -i example-key.pem ec2-user@$EC2IP
ec2-user$ 
```
### 2.3 encerrando a EC2 micro
```bash
$ EC2ID=$(aws ec2 describe-instances --query 'Reservations[0].Instances[0].InstanceId' --output text)
$ aws ec2 stop-instances --instance-ids $EC2ID
$ aws ec2 terminate-instances --instance-ids $EC2ID
```

```bash
$ tee -a app.py <<EOF
import json

def lambda_handler(event, context):
    first_name = event['first_name']
    last_name = event['last_name']

    message = f"Hello {first_name} {last_name}!"  

    return { 
        'message' : message
    }
EOF
```
```bash
$ tee -a template.yaml <<EOF
AWSTemplateFormatVersion : '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Resources:
  HelloNameFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: app.lambda_handler
      Runtime: python3.7
EOF
```
```bash
sam build
```


## Apêndice

Coloque qualquer informação adicional aqui


## Referência

 - [Developing AWS Lambda Functions Locally With VSCode](https://travis.media/developing-aws-lambda-functions-locally-vscode/)
 - [Launch and Manage EC2 Instances Using AWS CLI](https://medium.com/swlh/launch-and-manage-ec2-instances-using-aws-cli-7efae00e264b)

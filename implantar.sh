#!/bin/bash
touch app.py template.yaml
mkdir events && touch events/events.json

mkdir lambda_layerv1
tee -a lambda_layerv1/requirements.txt <<EOF
pillow == 9.0.1
boto3 == 1.21.23
EOF

echo -e "build-LambdaLayerv1:" > lambda_layerv1/Makefile
echo -e "\tmkdir -p \"\${ARTIFACTS_DIR}/python\"" >> lambda_layerv1/Makefile
echo -e "\tdocker run --user 1000:1000 -v \"$PWD\":/var/task \"lambci/lambda:build-python3.7\" /bin/sh -c \"pip install -r lambda_layerv1/requirements.txt -t .aws-sam/build/LambdaLayerv1/python; exit\"" >> lambda_layerv1/Makefile

tee -a app.py <<EOF
import boto3
import os
import sys
import uuid
from PIL import Image
import PIL.Image
     
s3_client = boto3.client('s3')
     
def resize_image(image_path, resized_path, width, height):
    with Image.open(image_path) as image:
        image.thumbnail((width, height),PIL.Image.ANTIALIAS)
        image.save(resized_path)

def thumb(bktOri, bktDest, keyFile, width, height):
    localFile           = '/tmp/{}{}'.format(uuid.uuid4(), keyFile)
    localFileResized    = '/tmp/resized-{}'.format(keyFile)
    s3_client.download_file(bktOri, keyFile, localFile)
    resize_image(localFile, localFileResized, width, height)
    s3_client.upload_file(localFileResized, bktDest, "thumb-"+keyFile)
    s3_client.delete_object(Bucket=bktOri, Key=keyFile)

def lambda_handler(event, context):
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key'] 
        
        thumb(bucket, 'bucket-store-imagesv1', key, 128, 128)

EOF
tee -a template.yaml <<EOF
AWSTemplateFormatVersion : '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Resources:
  BucketReceiveImagesv1S3Policy:
    Type: 'AWS::S3::BucketPolicy'
    Properties:
      Bucket: bucket-receive-imagesv1
      PolicyDocument:
        Statement:
          - Action:
              - 's3:*'
            Effect: 'Allow'
            Resource: !Sub 'arn:aws:s3:::\${BucketReceiveImagesv1}/*'
            Principal: '*'
  BucketReceiveImagesv1:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: bucket-receive-imagesv1

  BucketStoreImagesv1S3Policy:
    Type: 'AWS::S3::BucketPolicy'
    Properties:
      Bucket: bucket-store-imagesv1
      PolicyDocument:
        Statement:
          - Action:
              - 's3:*'
            Effect: 'Allow'
            Resource: !Sub 'arn:aws:s3:::\${BucketStoreImagesv1}/*'
            Principal: '*'
  BucketStoreImagesv1:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: bucket-store-imagesv1

  LambdaInvokePermission:
    Type: 'AWS::Lambda::Permission'
    Properties:
      FunctionName: !GetAtt LambdaPyv1Function.Arn
      Action: 'lambda:InvokeFunction'
      Principal: 's3.amazonaws.com'
      SourceAccount: !Ref 'AWS::AccountId'
      SourceArn: !GetAtt BucketReceiveImagesv1.Arn
  LambdaLayerv1:

    Type: AWS::Serverless::LayerVersion
    Properties:
      LayerName: lambda_layerv1
      ContentUri: lambda_layerv1
      CompatibleRuntimes:
        - python3.7
    Metadata:
      BuildMethod: makefile
  LambdaPyv1Function:
    Type: AWS::Serverless::Function
    Properties:
      Handler: app.lambda_handler
      Runtime: python3.7
      Timeout: 60
      MemorySize: 512
      Policies:
        - S3ReadPolicy:
            BucketName: bucket-receive-imagesv1
        - S3WritePolicy:
            BucketName: bucket-store-imagesv1
      Layers:
        - !Ref LambdaLayerv1
      Events:
        FileUpload:
          Type: S3
          Properties: 
            Bucket: !Ref BucketReceiveImagesv1
            Events: s3:ObjectCreated:*
EOF

curl -L 'https://images.pexels.com/photos/9754913/pexels-photo-9754913.jpeg?cs=srgb&dl=pexels-jonathan-cooper-9754913.jpg&fm=jpg&w=13440' -o base.jpg

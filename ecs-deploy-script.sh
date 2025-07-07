#!/bin/bash

# Set common variables
REGION="eu-west-1"
VPC_CIDR="10.0.0.0/16"
SUBNET1_CIDR="10.0.1.0/24"
SUBNET2_CIDR="10.0.2.0/24"
CLUSTER_NAME="your-cluster-name" # Replace with your actual cluster name
SERVICE_NAME="your-service-name" # Replace with your actual service name
TASK_NAME="your-task-name" # Replace with your actual task name
CONTAINER_NAME="your-container-name" # Replace with your actual container name
ECR_REPO="your-ecr-repo-name" # Replace with your actual ECR repository name
LOG_GROUP="your-log-group-name" # Replace with your actual log group name
SECRET_NAME="your-secret-name" # Replace with your actual secret name
RDS_DB_NAME="your_db_name" # Replace with your actual database name
RDS_USERNAME="your_db_username" # Replace with your actual database username
RDS_PASSWORD="your_secure_password"
DB_INSTANCE_ID="your-db-instance-id" # Replace with your actual DB instance ID
ROLE_NAME="your-ecs-task-execution-role" # Replace with your actual role name

# ─────────────────────────────────────────────────────
echo "🔧 Creating VPC..."
VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR \
  --query 'Vpc.VpcId' --output text)

aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=LAMP-VPC

# ─────────────────────────────────────────────────────
echo "📡 Creating subnets..."
SUBNET1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET1_CIDR \
  --availability-zone ${REGION}a \
  --query 'Subnet.SubnetId' --output text)

SUBNET2_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET2_CIDR \
  --availability-zone ${REGION}b \
  --query 'Subnet.SubnetId' --output text)

# ─────────────────────────────────────────────────────
echo "🌐 Creating Internet Gateway and route..."
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID

ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
aws ec2 associate-route-table --subnet-id $SUBNET1_ID --route-table-id $ROUTE_TABLE_ID
aws ec2 associate-route-table --subnet-id $SUBNET2_ID --route-table-id $ROUTE_TABLE_ID

# ─────────────────────────────────────────────────────
echo "🔒 Creating security group for RDS..."
RDS_SG_ID=$(aws ec2 create-security-group --group-name <your-security-group-name> \
  --description "Allow MySQL from Fargate" --vpc-id $VPC_ID \
  --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG_ID \
  --protocol tcp \
  --port 3306 \
  --cidr 0.0.0.0/0

# ─────────────────────────────────────────────────────
echo "🧩 Creating DB subnet group..."
aws rds create-db-subnet-group \
  --db-subnet-group-name <your DB subnet group name> \
  --db-subnet-group-description "DB subnet group" \
  --subnet-ids $SUBNET1_ID $SUBNET2_ID

# ─────────────────────────────────────────────────────
echo "🛢️ Creating RDS MySQL database..."
aws rds create-db-instance \
  --db-instance-identifier $DB_INSTANCE_ID \
  --db-instance-class db.t3.micro \
  --engine mysql \
  --master-username $RDS_USERNAME \
  --master-user-password $RDS_PASSWORD \
  --allocated-storage 20 \
  --vpc-security-group-ids $RDS_SG_ID \
  --db-subnet-group-name <your DB subnet group name> \
  --publicly-accessible \
  --backup-retention-period 7 \
  --multi-az \
  --storage-type gp2 \
  --region $REGION

# Wait until DB is available (optional)
echo "⏳ Waiting for RDS to be available..."
aws rds wait db-instance-available --db-instance-identifier $DB_INSTANCE_ID

RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier $DB_INSTANCE_ID \
  --query 'DBInstances[0].Endpoint.Address' --output text)

# ─────────────────────────────────────────────────────
echo "🔐 Creating Secrets Manager entry..."
aws secretsmanager create-secret \
  --name $SECRET_NAME \
  --description "DB creds for Lamp app" \
  --secret-string "{
    \"DB_HOST\": \"$RDS_ENDPOINT\",
    \"DB_USERNAME\": \"$RDS_USERNAME\",
    \"DB_PASSWORD\": \"$RDS_PASSWORD\",
    \"DB_DATABASE\": \"$RDS_DB_NAME\"
  }"

# ─────────────────────────────────────────────────────
echo "🔓 Attaching secret access policy to ecsTaskExecutionRole..."
SECRET_ARN="arn:aws:secretsmanager:$REGION:<user_id>:secret:$SECRET_NAME*"

aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name AllowReadLampstackDBSecret \
  --policy-document file://<(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "$SECRET_ARN"
    }
  ]
}
EOF
)

# Attach ECR and CloudWatch access
aws iam attach-role-policy --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

aws iam attach-role-policy --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess

# ─────────────────────────────────────────────────────
echo "📊 Creating CloudWatch log group..."
aws logs create-log-group --log-group-name $LOG_GROUP

# ─────────────────────────────────────────────────────
echo "🛠️ Create ECS cluster..."
aws ecs create-cluster --cluster-name $CLUSTER_NAME

# Note: Task definition registration and service creation should be done *after* the Docker image is built and pushed to ECR.
# You can use GitHub Actions to build the Docker image and push to ECR.

echo "✅ INFRASTRUCTURE SETUP COMPLETE!"
echo "📎 RDS Endpoint: $RDS_ENDPOINT"
echo "📎 Secret Name: $SECRET_NAME"
echo "📎 VPC ID: $VPC_ID"
echo "📎 Subnet A: $SUBNET1_ID"
echo "📎 Subnet B: $SUBNET2_ID"

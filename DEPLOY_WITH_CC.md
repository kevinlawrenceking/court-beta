# DocketWatch AWS Deployment — Claude Code Prompt Instructions

Copy-paste the section(s) below into Claude Code as prompts. Run them in order.
Each section is a self-contained prompt. Wait for one to finish before starting the next.

---

## Prerequisites Prompt

```
I need you to verify that all AWS CLI prerequisites are in place before deploying DocketWatch. Run the following checks and report results for each:

1. Verify AWS CLI v2 is installed:
   aws --version

2. Verify the AWS account identity and confirm we are in the correct account:
   aws sts get-caller-identity

3. Verify the AWS region is set to us-west-2:
   aws configure get region
   If not us-west-2, run: aws configure set region us-west-2

4. Verify Docker is installed and running:
   docker --version
   docker info

5. Verify Terraform >= 1.7.0 is installed:
   terraform --version

6. Verify Go >= 1.22 is installed:
   go version

7. Verify Flutter SDK is installed:
   flutter --version

8. Verify Python 3.12+ is installed:
   python3 --version

9. Verify the golang-migrate CLI is installed:
   migrate --version
   If not installed, run: go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest

10. Verify the GitHub CLI is installed (for CI/CD secrets):
    gh --version

Report a pass/fail for each item. Stop and tell me what to install if anything is missing.
```

---

## STEP 1: Create Terraform State Backend

```
Create the Terraform remote state backend for DocketWatch. This must exist before running terraform init.

Run these AWS CLI commands in order:

# 1. Create the S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket docketwatch-terraform-state \
  --region us-west-2 \
  --create-bucket-configuration LocationConstraint=us-west-2

# 2. Enable versioning on the state bucket
aws s3api put-bucket-versioning \
  --bucket docketwatch-terraform-state \
  --versioning-configuration Status=Enabled

# 3. Enable server-side encryption
aws s3api put-bucket-encryption \
  --bucket docketwatch-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "aws:kms"
        },
        "BucketKeyEnabled": true
      }
    ]
  }'

# 4. Block all public access
aws s3api put-public-access-block \
  --bucket docketwatch-terraform-state \
  --public-access-block-configuration '{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
  }'

# 5. Create the DynamoDB lock table
aws dynamodb create-table \
  --table-name docketwatch-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-west-2

# 6. Wait for the table to be active
aws dynamodb wait table-exists --table-name docketwatch-terraform-locks --region us-west-2

Verify both resources exist:
aws s3api head-bucket --bucket docketwatch-terraform-state
aws dynamodb describe-table --table-name docketwatch-terraform-locks --query 'Table.TableStatus'
```

---

## STEP 2: Create ECR Repositories and Build/Push Docker Images

```
Create ECR repositories and build+push all three Docker images for DocketWatch. Run these commands from the repo root (the court-beta directory).

# 1. Get the AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=us-west-2

# 2. Create ECR repositories
aws ecr create-repository --repository-name docketwatch-production-api --region $REGION --image-scanning-configuration scanOnPush=true
aws ecr create-repository --repository-name docketwatch-production-worker --region $REGION --image-scanning-configuration scanOnPush=true
aws ecr create-repository --repository-name docketwatch-production-python-worker --region $REGION --image-scanning-configuration scanOnPush=true

# 3. Log in to ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

# 4. Build and push the Go API image
cd go-api
go mod tidy
docker build --target api -t docketwatch-production-api:latest .
docker tag docketwatch-production-api:latest ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/docketwatch-production-api:latest
docker push ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/docketwatch-production-api:latest
cd ..

# 5. Build and push the Go Worker image
cd go-api
docker build --target worker -t docketwatch-production-worker:latest .
docker tag docketwatch-production-worker:latest ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/docketwatch-production-worker:latest
docker push ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/docketwatch-production-worker:latest
cd ..

# 6. Build and push the Python Worker image
cd python-workers
docker build -t docketwatch-production-python-worker:latest .
docker tag docketwatch-production-python-worker:latest ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/docketwatch-production-python-worker:latest
docker push ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/docketwatch-production-python-worker:latest
cd ..

# 7. Verify all images are in ECR
aws ecr list-images --repository-name docketwatch-production-api --region $REGION
aws ecr list-images --repository-name docketwatch-production-worker --region $REGION
aws ecr list-images --repository-name docketwatch-production-python-worker --region $REGION
```

---

## STEP 3: Create Terraform Variables File

```
Create the Terraform production variables file. Read the file infra/variables.tf first to see all available variables.

Then create the file infra/production.tfvars with this content (DO NOT commit this file — it may contain sensitive values):

aws_region         = "us-west-2"
environment        = "production"
project_name       = "docketwatch"
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-west-2a", "us-west-2b"]

# Database
db_instance_class = "db.t4g.medium"
db_name           = "docketwatch"
db_username       = "docketwatch_admin"

# ECS sizing
api_cpu           = 512
api_memory        = 1024
api_desired_count = 2
worker_cpu        = 256
worker_memory     = 512
python_worker_cpu    = 1024
python_worker_memory = 2048

# Domain (update these with your actual values)
domain_name     = "docketwatch.tmz.tv"
certificate_arn = ""

# SES
ses_sender_email = "alerts@docketwatch.tmz.tv"

Also add "production.tfvars" to infra/.gitignore if it doesn't exist. Create infra/.gitignore with:

*.tfvars
*.tfvars.json
.terraform/
*.tfstate
*.tfstate.backup
.terraform.lock.hcl

After creating the file, confirm its contents by reading it back.
```

---

## STEP 4: Run Terraform to Create All AWS Infrastructure

```
Deploy all AWS infrastructure for DocketWatch using Terraform. Run from the infra/ directory.

IMPORTANT: Review the plan carefully before applying. Do NOT auto-approve.

# 1. Initialize Terraform (downloads providers, configures backend)
cd infra
terraform init

# 2. Validate the configuration
terraform validate

# 3. Generate an execution plan — review every resource before proceeding
terraform plan -var-file=production.tfvars -out=tfplan

Show me the plan summary. I want to see the count of resources to add/change/destroy before I approve.

# 4. ONLY AFTER I APPROVE — Apply the plan
terraform apply tfplan

# 5. After apply completes, capture all outputs
terraform output -json > ../terraform-outputs.json

# 6. Print key outputs I'll need for the next steps
terraform output rds_endpoint
terraform output alb_dns_name
terraform output cloudfront_domain
terraform output cognito_user_pool_id
terraform output cognito_client_id
terraform output documents_bucket
terraform output sqs_summarize_queue_url

cd ..
```

---

## STEP 5: Run Database Migrations

```
Run the PostgreSQL database migrations against the new RDS instance.

First, I need to construct the DATABASE_URL. Read the Terraform outputs:

cd infra
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
DB_PASSWORD_ARN=$(terraform output -raw rds_password_secret_arn 2>/dev/null || echo "check-manually")
cd ..

The RDS password was auto-generated by Terraform and stored in AWS Secrets Manager. Retrieve it:

DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id docketwatch-production-db-password \
  --query SecretString --output text --region us-west-2)

Construct the full connection URL:

DATABASE_URL="postgres://docketwatch_admin:${DB_PASSWORD}@${RDS_ENDPOINT}/docketwatch?sslmode=require"

IMPORTANT: The RDS instance is in a private subnet. You must run the migration from a machine that has network access to the VPC. Options:
- An EC2 bastion host in the same VPC
- AWS CloudShell with VPC connector
- An SSH tunnel through a bastion
- Temporarily allow your IP in the RDS security group (NOT recommended for production)

If we have access, run the migration:

migrate -path go-api/migrations -database "${DATABASE_URL}" up

Verify the migration succeeded:

migrate -path go-api/migrations -database "${DATABASE_URL}" version

If the RDS instance is not directly accessible, create a bastion host:

# Create a small bastion EC2 instance in the public subnet
VPC_ID=$(cd infra && terraform output -raw vpc_id && cd ..)
PUBLIC_SUBNET=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=*public*" --query 'Subnets[0].SubnetId' --output text --region us-west-2)

aws ec2 run-instances \
  --image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64 \
  --instance-type t3.micro \
  --subnet-id ${PUBLIC_SUBNET} \
  --associate-public-ip-address \
  --iam-instance-profile Name=SSMInstanceProfile \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=docketwatch-bastion}]' \
  --region us-west-2

Then use SSM Session Manager to connect and run migrations from the bastion.
Tell me the result of each step.
```

---

## STEP 6: Create Cognito Users

```
Create the initial admin users in the Cognito User Pool.

# 1. Get the Cognito User Pool ID from Terraform outputs
cd infra
USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
cd ..

# 2. Create the first admin user (replace email and username)
aws cognito-idp admin-create-user \
  --user-pool-id ${USER_POOL_ID} \
  --username "admin@tmz.tv" \
  --user-attributes Name=email,Value="admin@tmz.tv" Name=email_verified,Value=true \
  --temporary-password "TempPass123!" \
  --message-action SUPPRESS \
  --region us-west-2

# 3. Set a permanent password for the admin user
aws cognito-idp admin-set-user-password \
  --user-pool-id ${USER_POOL_ID} \
  --username "admin@tmz.tv" \
  --password "CHANGE_ME_TO_A_STRONG_PASSWORD" \
  --permanent \
  --region us-west-2

# 4. Add the user to the admin group
aws cognito-idp admin-add-user-to-group \
  --user-pool-id ${USER_POOL_ID} \
  --username "admin@tmz.tv" \
  --group-name admin \
  --region us-west-2

# 5. Verify the user was created
aws cognito-idp admin-get-user \
  --user-pool-id ${USER_POOL_ID} \
  --username "admin@tmz.tv" \
  --region us-west-2

# 6. List all groups to confirm they exist
aws cognito-idp list-groups \
  --user-pool-id ${USER_POOL_ID} \
  --region us-west-2

Ask me for the actual email addresses and passwords before creating users. Do NOT use the placeholder values above.
```

---

## STEP 7: Build and Deploy Flutter Web SPA

```
Build the Flutter Web app and deploy it to the S3 SPA bucket, then invalidate CloudFront cache.

# 1. Get required values from Terraform
cd infra
COGNITO_USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
COGNITO_CLIENT_ID=$(terraform output -raw cognito_client_id)
CLOUDFRONT_DOMAIN=$(terraform output -raw cloudfront_domain)
CLOUDFRONT_DIST_ID=$(terraform output -raw distribution_id)
SPA_BUCKET=$(terraform output -raw spa_bucket 2>/dev/null || echo "docketwatch-production-spa")
cd ..

# 2. Build the Flutter Web app with production config
cd flutter-web
flutter pub get
flutter build web --release --web-renderer canvaskit \
  --dart-define=API_BASE_URL=https://${CLOUDFRONT_DOMAIN}/api \
  --dart-define=COGNITO_REGION=us-west-2 \
  --dart-define=COGNITO_USER_POOL_ID=${COGNITO_USER_POOL_ID} \
  --dart-define=COGNITO_CLIENT_ID=${COGNITO_CLIENT_ID}
cd ..

# 3. Upload static assets with long cache headers (JS, CSS, images, fonts, canvaskit)
aws s3 sync flutter-web/build/web/ s3://${SPA_BUCKET}/ \
  --exclude "index.html" \
  --exclude "flutter_service_worker.js" \
  --exclude "version.json" \
  --cache-control "public, max-age=31536000, immutable" \
  --region us-west-2

# 4. Upload index.html and service worker with no-cache (always get latest)
aws s3 cp flutter-web/build/web/index.html s3://${SPA_BUCKET}/index.html \
  --cache-control "no-cache, no-store, must-revalidate" \
  --content-type "text/html" \
  --region us-west-2

aws s3 cp flutter-web/build/web/flutter_service_worker.js s3://${SPA_BUCKET}/flutter_service_worker.js \
  --cache-control "no-cache, no-store, must-revalidate" \
  --content-type "application/javascript" \
  --region us-west-2

if [ -f flutter-web/build/web/version.json ]; then
  aws s3 cp flutter-web/build/web/version.json s3://${SPA_BUCKET}/version.json \
    --cache-control "no-cache, no-store, must-revalidate" \
    --content-type "application/json" \
    --region us-west-2
fi

# 5. Invalidate CloudFront cache for dynamic files
aws cloudfront create-invalidation \
  --distribution-id ${CLOUDFRONT_DIST_ID} \
  --paths "/index.html" "/flutter_service_worker.js" "/version.json" \
  --region us-east-1

# 6. Verify the deployment
echo "SPA deployed to: https://${CLOUDFRONT_DOMAIN}"
aws s3 ls s3://${SPA_BUCKET}/ --summarize --human-readable --region us-west-2
```

---

## STEP 8: Force ECS Service Deployments

```
Force new deployments of all three ECS services so they pick up the latest Docker images.

# 1. Get the ECS cluster name
CLUSTER=docketwatch-production

# 2. Force new deployment of the API service
aws ecs update-service \
  --cluster ${CLUSTER} \
  --service docketwatch-production-api \
  --force-new-deployment \
  --region us-west-2

# 3. Force new deployment of the Go Worker service
aws ecs update-service \
  --cluster ${CLUSTER} \
  --service docketwatch-production-worker \
  --force-new-deployment \
  --region us-west-2

# 4. Force new deployment of the Python Worker service
aws ecs update-service \
  --cluster ${CLUSTER} \
  --service docketwatch-production-python-worker \
  --force-new-deployment \
  --region us-west-2

# 5. Wait for all services to stabilize (this takes 2-5 minutes per service)
echo "Waiting for API service to stabilize..."
aws ecs wait services-stable \
  --cluster ${CLUSTER} \
  --services docketwatch-production-api \
  --region us-west-2
echo "API service is stable."

echo "Waiting for Worker service to stabilize..."
aws ecs wait services-stable \
  --cluster ${CLUSTER} \
  --services docketwatch-production-worker \
  --region us-west-2
echo "Worker service is stable."

echo "Waiting for Python Worker service to stabilize..."
aws ecs wait services-stable \
  --cluster ${CLUSTER} \
  --services docketwatch-production-python-worker \
  --region us-west-2
echo "Python Worker service is stable."

# 6. Verify all services are running
aws ecs describe-services \
  --cluster ${CLUSTER} \
  --services docketwatch-production-api docketwatch-production-worker docketwatch-production-python-worker \
  --query 'services[].{name:serviceName,status:status,running:runningCount,desired:desiredCount}' \
  --output table \
  --region us-west-2
```

---

## STEP 9: Verify SES Email Configuration

```
Verify and complete the SES email configuration for DocketWatch notifications.

# 1. Check if the domain identity exists
aws sesv2 get-email-identity \
  --email-identity docketwatch.tmz.tv \
  --region us-west-2

# 2. Get the DKIM tokens (these DNS records must be added to your domain)
aws sesv2 get-email-identity \
  --email-identity docketwatch.tmz.tv \
  --query 'DkimAttributes.Tokens' \
  --output text \
  --region us-west-2

Print the DKIM CNAME records that need to be added to DNS:
For each token, the DNS record is:
  Name:  {token}._domainkey.docketwatch.tmz.tv
  Type:  CNAME
  Value: {token}.dkim.amazonses.com

# 3. Check if we are still in the SES sandbox
aws sesv2 get-account \
  --query 'SendingEnabled' \
  --region us-west-2

# 4. If in sandbox (SendingEnabled=false or ProductionAccessEnabled=false), request production access:
echo "If SES is in sandbox mode, you must request production access via the AWS Console:"
echo "https://console.aws.amazon.com/ses/home?region=us-west-2#/account"
echo "Click 'Request production access' and fill out the form."

# 5. Verify the sender email address
aws sesv2 get-email-identity \
  --email-identity alerts@docketwatch.tmz.tv \
  --region us-west-2

# 6. Send a test email to verify it works
aws sesv2 send-email \
  --from-email-address "alerts@docketwatch.tmz.tv" \
  --destination '{"ToAddresses":["YOUR_TEST_EMAIL@tmz.tv"]}' \
  --content '{
    "Simple": {
      "Subject": {"Data": "DocketWatch SES Test"},
      "Body": {
        "Text": {"Data": "This is a test email from DocketWatch on AWS SES."},
        "Html": {"Data": "<h1>DocketWatch</h1><p>SES email is working.</p>"}
      }
    }
  }' \
  --region us-west-2

Ask me for the actual test email address before sending. Do NOT use the placeholder.
```

---

## STEP 10: Smoke Tests and Health Checks

```
Run smoke tests to verify the full DocketWatch deployment is working.

# 1. Get the ALB DNS name and CloudFront domain
cd infra
ALB_DNS=$(terraform output -raw alb_dns_name)
CF_DOMAIN=$(terraform output -raw cloudfront_domain)
cd ..

# 2. Test the API health endpoint directly via ALB
echo "Testing API health via ALB..."
curl -sf "http://${ALB_DNS}/health" && echo " -> PASS" || echo " -> FAIL"

# 3. Test the API health endpoint via CloudFront
echo "Testing API health via CloudFront..."
curl -sf "https://${CF_DOMAIN}/api/health" && echo " -> PASS" || echo " -> FAIL"

# 4. Test the SPA loads via CloudFront
echo "Testing SPA via CloudFront..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://${CF_DOMAIN}/")
if [ "$HTTP_CODE" = "200" ]; then echo "SPA -> PASS (HTTP $HTTP_CODE)"; else echo "SPA -> FAIL (HTTP $HTTP_CODE)"; fi

# 5. Test SPA routing (deep link should return index.html, not 404)
echo "Testing SPA deep routing..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://${CF_DOMAIN}/cases")
if [ "$HTTP_CODE" = "200" ]; then echo "SPA routing -> PASS"; else echo "SPA routing -> FAIL (HTTP $HTTP_CODE)"; fi

# 6. Test API returns JSON
echo "Testing API JSON response..."
curl -sf "https://${CF_DOMAIN}/api/health" -H "Accept: application/json" | python3 -m json.tool && echo "JSON -> PASS" || echo "JSON -> FAIL"

# 7. Check ECS task logs for errors
echo "Checking API logs for errors..."
aws logs filter-log-events \
  --log-group-name /ecs/docketwatch-production-api \
  --start-time $(date -d '10 minutes ago' +%s000 2>/dev/null || date -v-10M +%s000) \
  --filter-pattern "ERROR" \
  --limit 10 \
  --region us-west-2 \
  --query 'events[].message' \
  --output text

echo "Checking Worker logs for errors..."
aws logs filter-log-events \
  --log-group-name /ecs/docketwatch-production-worker \
  --start-time $(date -d '10 minutes ago' +%s000 2>/dev/null || date -v-10M +%s000) \
  --filter-pattern "ERROR" \
  --limit 10 \
  --region us-west-2 \
  --query 'events[].message' \
  --output text

echo "Checking Python Worker logs for errors..."
aws logs filter-log-events \
  --log-group-name /ecs/docketwatch-production-python-worker \
  --start-time $(date -d '10 minutes ago' +%s000 2>/dev/null || date -v-10M +%s000) \
  --filter-pattern "ERROR" \
  --limit 10 \
  --region us-west-2 \
  --query 'events[].message' \
  --output text

# 8. Verify RDS connectivity (from ECS task logs)
echo "Checking for DB connection errors..."
aws logs filter-log-events \
  --log-group-name /ecs/docketwatch-production-api \
  --start-time $(date -d '10 minutes ago' +%s000 2>/dev/null || date -v-10M +%s000) \
  --filter-pattern "database" \
  --limit 5 \
  --region us-west-2 \
  --query 'events[].message' \
  --output text

# 9. Print the final deployment URLs
echo ""
echo "========================================="
echo "  DocketWatch Deployment Complete"
echo "========================================="
echo "  App URL:     https://${CF_DOMAIN}"
echo "  API URL:     https://${CF_DOMAIN}/api"
echo "  Health:      https://${CF_DOMAIN}/api/health"
echo "  ALB Direct:  http://${ALB_DNS}"
echo "========================================="
```

---

## STEP 11: Set Up GitHub Actions CI/CD Secrets

```
Configure GitHub Actions secrets so that the CI/CD pipeline can deploy automatically on push to main.

The deploy.yml workflow uses OIDC (OpenID Connect) to authenticate with AWS — no long-lived access keys needed.

# 1. Create an OIDC identity provider in AWS for GitHub Actions
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  --region us-west-2

# 2. Create an IAM role for GitHub Actions
# Replace GITHUB_ORG and GITHUB_REPO with your actual values
GITHUB_ORG="kevinlawrenceking"
GITHUB_REPO="court-beta"

cat > /tmp/gh-actions-trust-policy.json << TRUSTEOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main"
        }
      }
    }
  ]
}
TRUSTEOF

aws iam create-role \
  --role-name docketwatch-github-actions-deploy \
  --assume-role-policy-document file:///tmp/gh-actions-trust-policy.json

# 3. Attach required policies to the role
# ECR: push images
aws iam attach-role-policy \
  --role-name docketwatch-github-actions-deploy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser

# ECS: update services
aws iam attach-role-policy \
  --role-name docketwatch-github-actions-deploy \
  --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess

# S3: deploy SPA
aws iam attach-role-policy \
  --role-name docketwatch-github-actions-deploy \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

# CloudFront: invalidate cache
cat > /tmp/cloudfront-policy.json << CFEOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "cloudfront:CreateInvalidation",
      "Resource": "arn:aws:cloudfront::${ACCOUNT_ID}:distribution/*"
    }
  ]
}
CFEOF

aws iam put-role-policy \
  --role-name docketwatch-github-actions-deploy \
  --policy-name CloudFrontInvalidation \
  --policy-document file:///tmp/cloudfront-policy.json

# 4. Get the role ARN
ROLE_ARN=$(aws iam get-role --role-name docketwatch-github-actions-deploy --query 'Role.Arn' --output text)
echo "Deploy Role ARN: ${ROLE_ARN}"

# 5. Get values needed for GitHub secrets
cd infra
DB_ENDPOINT=$(terraform output -raw rds_endpoint)
CF_DIST_ID=$(terraform output -raw distribution_id)
cd ..

DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id docketwatch-production-db-password \
  --query SecretString --output text --region us-west-2)

DATABASE_URL="postgres://docketwatch_admin:${DB_PASSWORD}@${DB_ENDPOINT}/docketwatch?sslmode=require"

# 6. Set GitHub Actions secrets using the gh CLI
gh secret set AWS_DEPLOY_ROLE_ARN --body "${ROLE_ARN}" --repo ${GITHUB_ORG}/${GITHUB_REPO}
gh secret set DATABASE_URL --body "${DATABASE_URL}" --repo ${GITHUB_ORG}/${GITHUB_REPO}
gh secret set CLOUDFRONT_DISTRIBUTION_ID --body "${CF_DIST_ID}" --repo ${GITHUB_ORG}/${GITHUB_REPO}

# 7. Verify secrets are set
gh secret list --repo ${GITHUB_ORG}/${GITHUB_REPO}

echo "CI/CD is now configured. Pushing to main will auto-deploy."
```

---

## STEP 12: DNS Configuration (Manual)

```
Print the DNS records I need to configure for docketwatch.tmz.tv.

# 1. Get the CloudFront distribution domain
cd infra
CF_DOMAIN=$(terraform output -raw cloudfront_domain)
cd ..

echo "Add the following DNS records to your domain registrar or Route 53:"
echo ""
echo "=== A Record (or CNAME) for the app ==="
echo "  Type:  CNAME"
echo "  Name:  docketwatch.tmz.tv"
echo "  Value: ${CF_DOMAIN}"
echo "  TTL:   300"
echo ""

# 2. Get DKIM tokens for SES
echo "=== SES DKIM Records (3 CNAME records) ==="
DKIM_TOKENS=$(aws sesv2 get-email-identity \
  --email-identity docketwatch.tmz.tv \
  --query 'DkimAttributes.Tokens' \
  --output text \
  --region us-west-2 2>/dev/null)

if [ -n "$DKIM_TOKENS" ]; then
  for TOKEN in $DKIM_TOKENS; do
    echo "  Type:  CNAME"
    echo "  Name:  ${TOKEN}._domainkey.docketwatch.tmz.tv"
    echo "  Value: ${TOKEN}.dkim.amazonses.com"
    echo ""
  done
fi

echo "=== SES Domain Verification (TXT record) ==="
SES_VERIFY=$(aws sesv2 get-email-identity \
  --email-identity docketwatch.tmz.tv \
  --query 'VerificationInfo.LastSuccessfulVerificationTime' \
  --output text \
  --region us-west-2 2>/dev/null)

echo "  Type:  TXT"
echo "  Name:  _amazonses.docketwatch.tmz.tv"
echo "  Value: (check SES console for verification token)"
echo ""

echo "=== ACM Certificate (if using HTTPS with custom domain) ==="
echo "  If you need an ACM certificate, run:"
echo "  aws acm request-certificate --domain-name docketwatch.tmz.tv --validation-method DNS --region us-east-1"
echo "  Then add the CNAME validation record from the output."
echo "  After validation, update infra/production.tfvars with the certificate_arn and re-apply Terraform."

echo ""
echo "After DNS propagation (5-60 minutes), the app will be live at:"
echo "  https://docketwatch.tmz.tv"
```

---

## Teardown Prompt (USE WITH CAUTION)

```
DANGER: This will destroy ALL DocketWatch AWS infrastructure. Only run this if you are sure.

I need you to tear down the DocketWatch deployment. Ask me to confirm TWICE before proceeding.

The steps are:

# 1. Disable deletion protection on RDS and ALB (Terraform has these enabled)
cd infra

# You must first modify the Terraform state to disable deletion protection,
# or manually disable it via AWS CLI:

RDS_INSTANCE=$(aws rds describe-db-instances \
  --query 'DBInstances[?DBName==`docketwatch`].DBInstanceIdentifier' \
  --output text --region us-west-2)

aws rds modify-db-instance \
  --db-instance-identifier ${RDS_INSTANCE} \
  --no-deletion-protection \
  --apply-immediately \
  --region us-west-2

ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names docketwatch-production \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text --region us-west-2)

aws elbv2 modify-load-balancer-attributes \
  --load-balancer-arn ${ALB_ARN} \
  --attributes Key=deletion_protection.enabled,Value=false \
  --region us-west-2

# 2. Empty all S3 buckets (Terraform cannot delete non-empty buckets)
aws s3 rm s3://docketwatch-production-documents --recursive --region us-west-2
aws s3 rm s3://docketwatch-production-uploads --recursive --region us-west-2
aws s3 rm s3://docketwatch-production-spa --recursive --region us-west-2

# 3. Destroy all infrastructure
terraform destroy -var-file=production.tfvars

# 4. Clean up the state backend (optional — only if fully decommissioning)
aws s3 rm s3://docketwatch-terraform-state --recursive
aws s3api delete-bucket --bucket docketwatch-terraform-state --region us-west-2
aws dynamodb delete-table --table-name docketwatch-terraform-locks --region us-west-2

# 5. Delete ECR repositories
aws ecr delete-repository --repository-name docketwatch-production-api --force --region us-west-2
aws ecr delete-repository --repository-name docketwatch-production-worker --force --region us-west-2
aws ecr delete-repository --repository-name docketwatch-production-python-worker --force --region us-west-2

# 6. Delete the GitHub Actions IAM role
aws iam detach-role-policy --role-name docketwatch-github-actions-deploy --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser
aws iam detach-role-policy --role-name docketwatch-github-actions-deploy --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess
aws iam detach-role-policy --role-name docketwatch-github-actions-deploy --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
aws iam delete-role-policy --role-name docketwatch-github-actions-deploy --policy-name CloudFrontInvalidation
aws iam delete-role --role-name docketwatch-github-actions-deploy

# 7. Delete OIDC provider
OIDC_ARN=$(aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)].Arn' --output text)
aws iam delete-open-id-connect-provider --open-id-connect-provider-arn ${OIDC_ARN}

echo "All DocketWatch infrastructure has been destroyed."
```

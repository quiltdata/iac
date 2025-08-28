# Quilt Platform Operations Guide

This document provides comprehensive operational procedures for cloud teams managing Quilt platform deployments.

## Quick Reference

### Emergency Procedures
- **Service Down**: [Jump to Service Recovery](#service-recovery)
- **Storage Full**: [Jump to Emergency Scaling](#emergency-scaling)
- **Security Incident**: [Jump to Security Response](#security-incident-response)

### Daily Checklist
- [ ] Health check (5 min) - [Instructions](#daily-health-checks)
- [ ] Monitor alerts - [Dashboard Links](#monitoring-dashboards)
- [ ] Review logs - [Log Locations](#log-management)

### Weekly Checklist
- [ ] Backup verification (10 min) - [Instructions](#backup-verification)
- [ ] Security updates (15 min) - [Instructions](#security-updates)
- [ ] Capacity review (10 min) - [Instructions](#capacity-monitoring)

### Monthly Checklist
- [ ] Capacity planning (20 min) - [Instructions](#capacity-planning)
- [ ] Cost review (15 min) - [Instructions](#cost-optimization)
- [ ] Security audit (30 min) - [Instructions](#security-audit)

## Installation Procedures

### Pre-Installation Checklist

**Infrastructure Requirements**
- [ ] AWS Account with appropriate permissions
- [ ] SSL Certificate in AWS Certificate Manager
- [ ] Domain name with DNS control
- [ ] S3 bucket for Terraform state
- [ ] CloudFormation template from Quilt

**Team Requirements**
- [ ] Terraform >= 1.5.0 installed
- [ ] AWS CLI configured
- [ ] Git repository for configuration
- [ ] Access to monitoring systems
- [ ] Emergency contact list updated

### Step-by-Step Installation

#### Phase 1: Environment Setup (30 minutes)

**1. Create Project Structure**
```bash
# Create dedicated directory
mkdir quilt-${ENVIRONMENT}
cd quilt-${ENVIRONMENT}

# Initialize git
git init
git remote add origin https://github.com/yourorg/quilt-${ENVIRONMENT}.git

# Create initial structure
mkdir -p {scripts,docs,backups}
```

**2. Download and Configure Templates**
```bash
# Download main configuration
curl -o main.tf https://raw.githubusercontent.com/quiltdata/iac/main/examples/main.tf

# Create environment-specific variables
cat > terraform.tfvars << EOF
# Environment: ${ENVIRONMENT}
# Created: $(date)
# Owner: ${TEAM_NAME}

google_client_secret = "${GOOGLE_CLIENT_SECRET}"
okta_client_secret   = "${OKTA_CLIENT_SECRET}"
EOF

# Create .gitignore
cat > .gitignore << 'EOF'
.terraform/
*.tfplan
*.tfstate
*.tfstate.backup
terraform.tfvars
.terraform.lock.hcl
*.log
EOF
```

**3. Configure main.tf**
```bash
# Edit main.tf with your values
vim main.tf

# Required updates:
# - allowed_account_ids: ["YOUR_AWS_ACCOUNT_ID"]
# - region: "YOUR_AWS_REGION"
# - bucket: "YOUR_TERRAFORM_STATE_BUCKET"
# - local.name: "quilt-${ENVIRONMENT}"
# - local.quilt_web_host: "data-${ENVIRONMENT}.yourcompany.com"
# - CertificateArnELB: "YOUR_CERTIFICATE_ARN"
# - AdminEmail: "admin@yourcompany.com"
# - zone_id: "YOUR_ROUTE53_ZONE_ID"
```

#### Phase 2: Infrastructure Deployment (45 minutes)

**1. Initialize Terraform**
```bash
# Initialize
terraform init

# Validate syntax
terraform validate

# Format code
terraform fmt

# Security scan (if available)
# tfsec . || echo "Security scan not available"
```

**2. Plan Deployment**
```bash
# Create plan
terraform plan -out=tfplan

# Review plan output carefully
# Check for:
# - No unexpected deletions
# - Correct resource counts
# - Proper naming conventions
# - Security group configurations
```

**3. Deploy Infrastructure**
```bash
# Apply configuration
terraform apply tfplan

# Monitor deployment progress
# Typical deployment time: 20-30 minutes
# Watch AWS Console for resource creation status
```

**4. Verify Deployment**
```bash
# Get deployment outputs
terraform output admin_password > admin_password.txt
chmod 600 admin_password.txt
terraform output quilt_url

# Test connectivity
QUILT_URL=$(terraform output -raw quilt_url)
curl -I "${QUILT_URL}" || echo "Service not yet ready"

# Wait for service to be fully ready (up to 10 minutes)
for i in {1..20}; do
  if curl -f "${QUILT_URL}/health" >/dev/null 2>&1; then
    echo "Service is ready!"
    break
  fi
  echo "Waiting for service... (attempt $i/20)"
  sleep 30
done
```

#### Phase 3: Initial Configuration (15 minutes)

**1. Access Quilt Catalog**
```bash
# Get credentials
ADMIN_EMAIL=$(terraform output -raw admin_email)
ADMIN_PASSWORD=$(cat admin_password.txt)
QUILT_URL=$(terraform output -raw quilt_url)

echo "Access Quilt at: ${QUILT_URL}"
echo "Username: ${ADMIN_EMAIL}"
echo "Password: ${ADMIN_PASSWORD}"
```

**2. Initial Setup Tasks**
- [ ] Login to Quilt catalog
- [ ] Change default admin password
- [ ] Configure organization settings
- [ ] Set up initial users and permissions
- [ ] Test basic functionality (upload/download)

**3. Documentation**
```bash
# Create deployment documentation
cat > docs/deployment-info.md << EOF
# Quilt Deployment Information

**Environment**: ${ENVIRONMENT}
**Deployed**: $(date)
**Version**: $(git describe --tags 2>/dev/null || echo "latest")

## Access Information
- **URL**: ${QUILT_URL}
- **Admin Email**: ${ADMIN_EMAIL}
- **AWS Region**: $(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")

## Infrastructure
- **VPC ID**: $(terraform show -json | jq -r '.values.root_module.child_modules[] | select(.address=="module.quilt") | .child_modules[] | select(.address=="module.vpc") | .resources[] | select(.type=="aws_vpc") | .values.id' 2>/dev/null || echo "N/A")
- **Database**: $(terraform show -json | jq -r '.values.root_module.child_modules[] | select(.address=="module.quilt") | .child_modules[] | select(.address=="module.db") | .resources[] | select(.type=="aws_db_instance") | .values.identifier' 2>/dev/null || echo "N/A")
- **ElasticSearch**: $(terraform show -json | jq -r '.values.root_module.child_modules[] | select(.address=="module.quilt") | .child_modules[] | select(.address=="module.search") | .resources[] | select(.type=="aws_elasticsearch_domain") | .values.domain_name' 2>/dev/null || echo "N/A")

## Next Steps
1. Configure monitoring and alerting
2. Set up backup procedures
3. Configure user access
4. Test disaster recovery procedures
EOF
```

## Maintenance Procedures

### Daily Operations

#### Daily Health Checks (5 minutes)

**Automated Health Check Script**
```bash
#!/bin/bash
# File: scripts/daily-health-check.sh

set -e

QUILT_URL=$(terraform output -raw quilt_url)
STACK_NAME=$(terraform output -raw stack_name 2>/dev/null || echo "quilt-prod")

echo "=== Daily Health Check - $(date) ==="

# 1. Infrastructure Status
echo "Checking infrastructure status..."
terraform refresh >/dev/null
if terraform plan -detailed-exitcode >/dev/null; then
  echo "✓ Infrastructure: No drift detected"
else
  echo "⚠ Infrastructure: Drift detected - review required"
fi

# 2. Application Health
echo "Checking application health..."
if curl -f "${QUILT_URL}/health" >/dev/null 2>&1; then
  echo "✓ Application: Healthy"
else
  echo "✗ Application: Health check failed"
fi

# 3. ElasticSearch Health
echo "Checking ElasticSearch health..."
ES_STATUS=$(aws es describe-elasticsearch-domain --domain-name "${STACK_NAME}" --query 'DomainStatus.Processing' --output text 2>/dev/null || echo "unknown")
if [ "$ES_STATUS" = "False" ]; then
  echo "✓ ElasticSearch: Ready"
else
  echo "⚠ ElasticSearch: Processing or unavailable"
fi

# 4. Database Health
echo "Checking database health..."
DB_STATUS=$(aws rds describe-db-instances --db-instance-identifier "${STACK_NAME}" --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || echo "unknown")
if [ "$DB_STATUS" = "available" ]; then
  echo "✓ Database: Available"
else
  echo "⚠ Database: Status is $DB_STATUS"
fi

echo "=== Health Check Complete ==="
```

**Usage:**
```bash
# Make script executable
chmod +x scripts/daily-health-check.sh

# Run daily health check
./scripts/daily-health-check.sh

# Add to crontab for automation
# 0 9 * * * cd /path/to/quilt-prod && ./scripts/daily-health-check.sh >> logs/health-check.log 2>&1
```

#### Log Management

**Application Logs**
```bash
# View ECS service logs
aws logs describe-log-groups --log-group-name-prefix "/aws/ecs/quilt"

# Stream recent logs
aws logs tail "/aws/ecs/quilt-prod" --follow

# Search for errors
aws logs filter-log-events \
  --log-group-name "/aws/ecs/quilt-prod" \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --filter-pattern "ERROR"
```

**Infrastructure Logs**
```bash
# CloudTrail logs
aws logs filter-log-events \
  --log-group-name "CloudTrail/QuiltAuditLogs" \
  --start-time $(date -d '24 hours ago' +%s)000 \
  --filter-pattern "{ $.eventName = CreateDBInstance || $.eventName = ModifyDBInstance }"

# VPC Flow Logs (if enabled)
aws logs describe-log-groups --log-group-name-prefix "/aws/vpc/flowlogs"
```

### Weekly Maintenance

#### Backup Verification (10 minutes)

**Database Backup Check**
```bash
#!/bin/bash
# File: scripts/verify-backups.sh

STACK_NAME=$(terraform output -raw stack_name 2>/dev/null || echo "quilt-prod")

echo "=== Backup Verification - $(date) ==="

# Check RDS automated backups
echo "Checking RDS automated backups..."
BACKUP_COUNT=$(aws rds describe-db-snapshots \
  --db-instance-identifier "${STACK_NAME}" \
  --snapshot-type automated \
  --query 'length(DBSnapshots)' \
  --output text)

if [ "$BACKUP_COUNT" -gt 0 ]; then
  echo "✓ RDS: $BACKUP_COUNT automated backups found"
  
  # Show latest backup
  LATEST_BACKUP=$(aws rds describe-db-snapshots \
    --db-instance-identifier "${STACK_NAME}" \
    --snapshot-type automated \
    --query 'DBSnapshots | sort_by(@, &SnapshotCreateTime) | [-1].{Time:SnapshotCreateTime,Status:Status}' \
    --output table)
  echo "$LATEST_BACKUP"
else
  echo "⚠ RDS: No automated backups found"
fi

# Check manual snapshots
MANUAL_COUNT=$(aws rds describe-db-snapshots \
  --db-instance-identifier "${STACK_NAME}" \
  --snapshot-type manual \
  --query 'length(DBSnapshots)' \
  --output text)

echo "✓ RDS: $MANUAL_COUNT manual snapshots available"

# Verify Terraform state backup
echo "Checking Terraform state backup..."
STATE_BUCKET=$(terraform backend config -get bucket 2>/dev/null || echo "unknown")
if aws s3 ls "s3://${STATE_BUCKET}/quilt/terraform.tfstate" >/dev/null 2>&1; then
  echo "✓ Terraform: State file accessible"
else
  echo "⚠ Terraform: State file not accessible"
fi

echo "=== Backup Verification Complete ==="
```

#### Security Updates (15 minutes)

**Update Check Script**
```bash
#!/bin/bash
# File: scripts/check-updates.sh

echo "=== Security Update Check - $(date) ==="

# Check Terraform module updates
echo "Checking Terraform module updates..."
CURRENT_VERSION=$(grep 'ref=' main.tf | head -1 | sed 's/.*ref=//' | tr -d '"')
echo "Current version: $CURRENT_VERSION"

# Check latest release (requires gh CLI or manual check)
echo "Latest releases: https://github.com/quiltdata/iac/releases"

# Check AWS security bulletins
echo "Check AWS security bulletins:"
echo "- https://aws.amazon.com/security/security-bulletins/"
echo "- Review RDS, ElasticSearch, and ECS security updates"

# Check for outdated AMIs
echo "Checking ECS optimized AMI updates..."
aws ssm get-parameter \
  --name "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended" \
  --query 'Parameter.Value' \
  --output text | jq '.image_id'

echo "=== Update Check Complete ==="
```

### Monthly Maintenance

#### Capacity Planning (20 minutes)

**Capacity Analysis Script**
```bash
#!/bin/bash
# File: scripts/capacity-analysis.sh

STACK_NAME=$(terraform output -raw stack_name 2>/dev/null || echo "quilt-prod")
START_TIME=$(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S)
END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)

echo "=== Capacity Analysis - $(date) ==="
echo "Analysis period: $START_TIME to $END_TIME"

# ElasticSearch storage utilization
echo "ElasticSearch Storage Utilization:"
aws cloudwatch get-metric-statistics \
  --namespace AWS/ES \
  --metric-name StorageUtilization \
  --dimensions Name=DomainName,Value="$STACK_NAME" Name=ClientId,Value="$(aws sts get-caller-identity --query Account --output text)" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 86400 \
  --statistics Average,Maximum \
  --query 'Datapoints | sort_by(@, &Timestamp) | [-5:]' \
  --output table

# RDS CPU utilization
echo "RDS CPU Utilization:"
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value="$STACK_NAME" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 86400 \
  --statistics Average,Maximum \
  --query 'Datapoints | sort_by(@, &Timestamp) | [-5:]' \
  --output table

# RDS connections
echo "RDS Database Connections:"
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value="$STACK_NAME" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 86400 \
  --statistics Average,Maximum \
  --query 'Datapoints | sort_by(@, &Timestamp) | [-5:]' \
  --output table

# Generate recommendations
echo "=== Capacity Recommendations ==="
echo "Review the above metrics and consider:"
echo "- ElasticSearch storage > 80%: Plan storage scaling"
echo "- RDS CPU > 70%: Consider instance upgrade"
echo "- RDS connections > 80% of max: Review connection pooling"

echo "=== Capacity Analysis Complete ==="
```

## Scaling Procedures

### Emergency Scaling

#### ElasticSearch Storage Emergency Scaling

**When**: Storage utilization > 90% or disk space alerts

**Immediate Actions (15 minutes)**
```bash
#!/bin/bash
# File: scripts/emergency-es-scaling.sh

STACK_NAME=$(terraform output -raw stack_name 2>/dev/null || echo "quilt-prod")

echo "=== EMERGENCY: ElasticSearch Storage Scaling ==="

# 1. Check current status
echo "Current ElasticSearch status:"
aws es describe-elasticsearch-domain --domain-name "$STACK_NAME" \
  --query 'DomainStatus.{Status:DomainStatus,Storage:EBSOptions,Processing:Processing}' \
  --output table

# 2. Get current storage size
CURRENT_SIZE=$(terraform show -json | jq -r '.values.root_module.child_modules[] | select(.address=="module.quilt") | .resources[] | select(.name=="search_volume_size") | .values // empty')
echo "Current storage size: ${CURRENT_SIZE}GB"

# 3. Calculate new size (increase by 50%)
NEW_SIZE=$((CURRENT_SIZE * 3 / 2))
echo "Recommended new size: ${NEW_SIZE}GB"

# 4. Update configuration
echo "Updating main.tf..."
sed -i.backup "s/search_volume_size.*=.*/search_volume_size = $NEW_SIZE/" main.tf

# 5. Plan and apply
echo "Planning scaling operation..."
terraform plan -out=emergency-scaling.tfplan

echo "Ready to apply scaling. This will cause temporary performance impact."
echo "Run: terraform apply emergency-scaling.tfplan"
echo "Monitor progress with: aws es describe-elasticsearch-domain --domain-name $STACK_NAME"
```

#### Database Emergency Scaling

**When**: CPU > 90% or connection limit reached

**Immediate Actions (10 minutes)**
```bash
#!/bin/bash
# File: scripts/emergency-db-scaling.sh

STACK_NAME=$(terraform output -raw stack_name 2>/dev/null || echo "quilt-prod")

echo "=== EMERGENCY: Database Scaling ==="

# 1. Check current status
echo "Current database status:"
aws rds describe-db-instances --db-instance-identifier "$STACK_NAME" \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Class:DBInstanceClass,CPU:ProcessorFeatures}' \
  --output table

# 2. Get current instance class
CURRENT_CLASS=$(terraform show -json | jq -r '.values.root_module.child_modules[] | select(.address=="module.quilt") | .resources[] | select(.name=="db_instance_class") | .values // empty')
echo "Current instance class: $CURRENT_CLASS"

# 3. Suggest upgrade path
case $CURRENT_CLASS in
  "db.t3.micro") NEW_CLASS="db.t3.small" ;;
  "db.t3.small") NEW_CLASS="db.t3.medium" ;;
  "db.t3.medium") NEW_CLASS="db.t3.large" ;;
  "db.t3.large") NEW_CLASS="db.r5.large" ;;
  *) NEW_CLASS="db.r5.xlarge" ;;
esac

echo "Recommended upgrade: $CURRENT_CLASS -> $NEW_CLASS"

# 4. Update configuration
echo "Updating main.tf..."
sed -i.backup "s/db_instance_class.*=.*/db_instance_class = \"$NEW_CLASS\"/" main.tf

echo "Ready to apply scaling. This will cause brief downtime."
echo "Run: terraform plan -out=emergency-db-scaling.tfplan"
echo "Then: terraform apply emergency-db-scaling.tfplan"
```

### Planned Scaling

#### Quarterly Capacity Review

**Capacity Planning Worksheet**
```bash
#!/bin/bash
# File: scripts/quarterly-capacity-review.sh

echo "=== Quarterly Capacity Review - $(date) ==="

# Data collection period (90 days)
START_TIME=$(date -u -d '90 days ago' +%Y-%m-%dT%H:%M:%S)
END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)

# Create capacity report
cat > "capacity-report-$(date +%Y%m%d).md" << EOF
# Quarterly Capacity Review

**Period**: $START_TIME to $END_TIME
**Generated**: $(date)

## Current Configuration

### ElasticSearch
- **Instance Count**: $(terraform show -json | jq -r '.values.root_module.child_modules[] | select(.address=="module.quilt") | .resources[] | select(.name=="search_instance_count") | .values // "N/A"')
- **Instance Type**: $(terraform show -json | jq -r '.values.root_module.child_modules[] | select(.address=="module.quilt") | .resources[] | select(.name=="search_instance_type") | .values // "N/A"')
- **Volume Size**: $(terraform show -json | jq -r '.values.root_module.child_modules[] | select(.address=="module.quilt") | .resources[] | select(.name=="search_volume_size") | .values // "N/A"')GB

### Database
- **Instance Class**: $(terraform show -json | jq -r '.values.root_module.child_modules[] | select(.address=="module.quilt") | .resources[] | select(.name=="db_instance_class") | .values // "N/A"')
- **Multi-AZ**: $(terraform show -json | jq -r '.values.root_module.child_modules[] | select(.address=="module.quilt") | .resources[] | select(.name=="db_multi_az") | .values // "N/A"')

## Utilization Metrics

### Storage Utilization Trends
EOF

# Add metrics to report
aws cloudwatch get-metric-statistics \
  --namespace AWS/ES \
  --metric-name StorageUtilization \
  --dimensions Name=DomainName,Value="$(terraform output -raw stack_name 2>/dev/null || echo "quilt-prod")" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 604800 \
  --statistics Average,Maximum \
  --output table >> "capacity-report-$(date +%Y%m%d).md"

echo "Capacity report generated: capacity-report-$(date +%Y%m%d).md"
echo "Review and plan scaling operations based on trends."
```

## Disaster Recovery

### Service Recovery

#### Complete Service Outage

**Recovery Procedure (30-60 minutes)**

**Step 1: Assess Situation (5 minutes)**
```bash
# Check overall service status
QUILT_URL=$(terraform output -raw quilt_url)
curl -I "$QUILT_URL" || echo "Service unreachable"

# Check infrastructure components
terraform refresh
terraform plan -detailed-exitcode || echo "Infrastructure drift detected"

# Check AWS service health
aws health describe-events --filter services=EC2,RDS,ES --query 'events[?eventTypeCategory==`issue`]'
```

**Step 2: Component-Level Diagnosis (10 minutes)**
```bash
STACK_NAME=$(terraform output -raw stack_name 2>/dev/null || echo "quilt-prod")

# Check ECS services
aws ecs describe-services --cluster "$STACK_NAME" --services "$STACK_NAME"

# Check database
aws rds describe-db-instances --db-instance-identifier "$STACK_NAME"

# Check ElasticSearch
aws es describe-elasticsearch-domain --domain-name "$STACK_NAME"

# Check load balancer
aws elbv2 describe-load-balancers --names "$STACK_NAME"
```

**Step 3: Recovery Actions**
```bash
# If infrastructure drift detected
terraform apply -auto-approve

# If ECS service issues
aws ecs update-service --cluster "$STACK_NAME" --service "$STACK_NAME" --force-new-deployment

# If database issues
# (Manual intervention required - check RDS console)

# If ElasticSearch issues
# (Manual intervention required - check ES console)
```

#### Database Recovery from Backup

**Recovery Procedure (45-90 minutes)**

**Step 1: Identify Recovery Point**
```bash
STACK_NAME=$(terraform output -raw stack_name 2>/dev/null || echo "quilt-prod")

# List available snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier "$STACK_NAME" \
  --query 'DBSnapshots | sort_by(@, &SnapshotCreateTime) | [-10:]' \
  --output table

# Select snapshot for recovery
read -p "Enter snapshot identifier: " SNAPSHOT_ID
```

**Step 2: Update Configuration**
```bash
# Backup current configuration
cp main.tf main.tf.backup

# Add snapshot identifier to configuration
sed -i '/db_instance_class/a \ \ db_snapshot_identifier = "'$SNAPSHOT_ID'"' main.tf

# Plan recovery
terraform plan -out=recovery.tfplan
```

**Step 3: Execute Recovery**
```bash
# Apply recovery configuration
terraform apply recovery.tfplan

# Monitor recovery progress
aws rds describe-db-instances --db-instance-identifier "$STACK_NAME" \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Progress:StatusInfos}'
```

**Step 4: Verify Recovery**
```bash
# Test database connectivity
QUILT_URL=$(terraform output -raw quilt_url)
curl -f "$QUILT_URL/health" || echo "Service not ready yet"

# Remove snapshot identifier from config
sed -i '/db_snapshot_identifier/d' main.tf
```

### Security Incident Response

#### Suspected Compromise

**Immediate Actions (15 minutes)**

**Step 1: Isolate and Assess**
```bash
# Get current security group rules
STACK_NAME=$(terraform output -raw stack_name 2>/dev/null || echo "quilt-prod")
aws ec2 describe-security-groups --filters "Name=group-name,Values=*$STACK_NAME*"

# Check recent access logs
aws logs filter-log-events \
  --log-group-name "/aws/ecs/$STACK_NAME" \
  --start-time $(date -d '2 hours ago' +%s)000 \
  --filter-pattern "ERROR"

# Check CloudTrail for suspicious activity
aws logs filter-log-events \
  --log-group-name "CloudTrail/QuiltAuditLogs" \
  --start-time $(date -d '24 hours ago' +%s)000 \
  --filter-pattern "{ $.sourceIPAddress != \"10.*\" && $.sourceIPAddress != \"172.*\" && $.sourceIPAddress != \"192.168.*\" }"
```

**Step 2: Immediate Containment**
```bash
# Temporarily restrict access (if needed)
# Update security groups to allow only known IPs
# This should be done through Terraform for consistency

# Force password reset for admin account
# (Done through Quilt UI)

# Rotate API keys and secrets
# (Update terraform.tfvars and re-apply)
```

**Step 3: Evidence Collection**
```bash
# Export recent logs
aws logs create-export-task \
  --log-group-name "/aws/ecs/$STACK_NAME" \
  --from $(date -d '7 days ago' +%s)000 \
  --to $(date +%s)000 \
  --destination "security-incident-$(date +%Y%m%d)" \
  --destination-prefix "logs/"

# Snapshot current state
terraform show > "terraform-state-$(date +%Y%m%d-%H%M).txt"

# Create database snapshot
aws rds create-db-snapshot \
  --db-instance-identifier "$STACK_NAME" \
  --db-snapshot-identifier "$STACK_NAME-incident-$(date +%Y%m%d)"
```

## Monitoring and Alerting

### Monitoring Dashboards

#### CloudWatch Dashboard Setup
```bash
#!/bin/bash
# File: scripts/setup-monitoring.sh

STACK_NAME=$(terraform output -raw stack_name 2>/dev/null || echo "quilt-prod")
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)

# Create CloudWatch dashboard
cat > dashboard-config.json << EOF
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/ES", "StorageUtilization", "DomainName", "$STACK_NAME", "ClientId", "$AWS_ACCOUNT"],
          ["AWS/ES", "ClusterStatus.yellow", "DomainName", "$STACK_NAME", "ClientId", "$AWS_ACCOUNT"],
          ["AWS/ES", "ClusterStatus.red", "DomainName", "$STACK_NAME", "ClientId", "$AWS_ACCOUNT"]
        ],
        "period": 300,
        "stat": "Average",
        "region": "$AWS_REGION",
        "title": "ElasticSearch Health"
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "$STACK_NAME"],
          ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", "$STACK_NAME"],
          ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", "$STACK_NAME"]
        ],
        "period": 300,
        "stat": "Average",
        "region": "$AWS_REGION",
        "title": "RDS Performance"
      }
    }
  ]
}
EOF

# Create dashboard
aws cloudwatch put-dashboard \
  --dashboard-name "Quilt-$STACK_NAME" \
  --dashboard-body file://dashboard-config.json

echo "Dashboard created: https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#dashboards:name=Quilt-$STACK_NAME"
```

#### Alert Configuration
```bash
#!/bin/bash
# File: scripts/setup-alerts.sh

STACK_NAME=$(terraform output -raw stack_name 2>/dev/null || echo "quilt-prod")
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)

# Create SNS topic for alerts
SNS_TOPIC_ARN=$(aws sns create-topic --name "quilt-$STACK_NAME-alerts" --query 'TopicArn' --output text)

# Subscribe email to topic
read -p "Enter email for alerts: " ALERT_EMAIL
aws sns subscribe --topic-arn "$SNS_TOPIC_ARN" --protocol email --notification-endpoint "$ALERT_EMAIL"

# ElasticSearch storage alert
aws cloudwatch put-metric-alarm \
  --alarm-name "Quilt-$STACK_NAME-ES-Storage-High" \
  --alarm-description "ElasticSearch storage utilization > 80%" \
  --metric-name StorageUtilization \
  --namespace AWS/ES \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=DomainName,Value="$STACK_NAME" Name=ClientId,Value="$AWS_ACCOUNT" \
  --evaluation-periods 2 \
  --alarm-actions "$SNS_TOPIC_ARN"

# RDS CPU alert
aws cloudwatch put-metric-alarm \
  --alarm-name "Quilt-$STACK_NAME-RDS-CPU-High" \
  --alarm-description "RDS CPU utilization > 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/RDS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=DBInstanceIdentifier,Value="$STACK_NAME" \
  --evaluation-periods 2 \
  --alarm-actions "$SNS_TOPIC_ARN"

echo "Alerts configured. Check email for subscription confirmation."
```

### Performance Monitoring

#### Application Performance Monitoring
```bash
#!/bin/bash
# File: scripts/performance-monitoring.sh

QUILT_URL=$(terraform output -raw quilt_url)
STACK_NAME=$(terraform output -raw stack_name 2>/dev/null || echo "quilt-prod")

echo "=== Performance Monitoring Report - $(date) ==="

# Response time check
echo "Checking response times..."
for endpoint in "/" "/health" "/api/status"; do
  RESPONSE_TIME=$(curl -o /dev/null -s -w "%{time_total}" "$QUILT_URL$endpoint" 2>/dev/null || echo "failed")
  echo "  $endpoint: ${RESPONSE_TIME}s"
done

# ECS service metrics
echo "ECS Service Status:"
aws ecs describe-services \
  --cluster "$STACK_NAME" \
  --services "$STACK_NAME" \
  --query 'services[0].{Running:runningCount,Desired:desiredCount,Status:status}' \
  --output table

# Load balancer metrics
echo "Load Balancer Health:"
aws elbv2 describe-target-health \
  --target-group-arn "$(aws elbv2 describe-target-groups --names "$STACK_NAME" --query 'TargetGroups[0].TargetGroupArn' --output text)" \
  --query 'TargetHealthDescriptions[].{Target:Target.Id,Health:TargetHealth.State}' \
  --output table

echo "=== Performance Monitoring Complete ==="
```

## Cost Management

### Cost Monitoring

#### Monthly Cost Analysis
```bash
#!/bin/bash
# File: scripts/cost-analysis.sh

STACK_NAME=$(terraform output -raw stack_name 2>/dev/null || echo "quilt-prod")
CURRENT_MONTH=$(date +%Y-%m-01)
NEXT_MONTH=$(date -d "next month" +%Y-%m-01)

echo "=== Monthly Cost Analysis - $(date) ==="

# Get costs by service for current month
aws ce get-cost-and-usage \
  --time-period Start="$CURRENT_MONTH",End="$NEXT_MONTH" \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --filter file://<(cat << EOF
{
  "Dimensions": {
    "Key": "RESOURCE_ID",
    "Values": ["*$STACK_NAME*"]
  }
}
EOF
) \
  --query 'ResultsByTime[0].Groups[?Metrics.BlendedCost.Amount>`0`]' \
  --output table

# Get daily costs for trend analysis
aws ce get-cost-and-usage \
  --time-period Start="$(date -d '30 days ago' +%Y-%m-%d)",End="$(date +%Y-%m-%d)" \
  --granularity DAILY \
  --metrics BlendedCost \
  --filter file://<(cat << EOF
{
  "Dimensions": {
    "Key": "RESOURCE_ID",
    "Values": ["*$STACK_NAME*"]
  }
}
EOF
) \
  --query 'ResultsByTime[-7:].{Date:TimePeriod.Start,Cost:Total.BlendedCost.Amount}' \
  --output table

echo "=== Cost Analysis Complete ==="
```

#### Cost Optimization Recommendations
```bash
#!/bin/bash
# File: scripts/cost-optimization.sh

echo "=== Cost Optimization Recommendations ==="

# Check for unused EBS volumes
echo "Checking for unused EBS volumes..."
aws ec2 describe-volumes \
  --filters Name=status,Values=available \
  --query 'Volumes[].{VolumeId:VolumeId,Size:Size,Type:VolumeType,CreateTime:CreateTime}' \
  --output table

# Check for unattached Elastic IPs
echo "Checking for unattached Elastic IPs..."
aws ec2 describe-addresses \
  --query 'Addresses[?!InstanceId].{IP:PublicIp,AllocationId:AllocationId}' \
  --output table

# RDS instance recommendations
echo "RDS Instance Analysis:"
STACK_NAME=$(terraform output -raw stack_name 2>/dev/null || echo "quilt-prod")
aws rds describe-db-instances \
  --db-instance-identifier "$STACK_NAME" \
  --query 'DBInstances[0].{Class:DBInstanceClass,MultiAZ:MultiAZ,Storage:AllocatedStorage,IOPS:Iops}' \
  --output table

echo "Optimization Recommendations:"
echo "1. Consider Reserved Instances for long-running resources"
echo "2. Review ElasticSearch instance types for right-sizing"
echo "3. Implement S3 lifecycle policies for log retention"
echo "4. Use Spot Instances for non-critical workloads"

echo "=== Cost Optimization Complete ==="
```

## Team Procedures

### Onboarding New Team Members

#### Access Setup Checklist
- [ ] AWS IAM user created with appropriate permissions
- [ ] Terraform access configured
- [ ] Git repository access granted
- [ ] Monitoring dashboard access provided
- [ ] Emergency contact list updated
- [ ] Training on procedures completed

#### Required Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "rds:*",
        "es:*",
        "ecs:*",
        "elbv2:*",
        "cloudwatch:*",
        "logs:*",
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:RequestedRegion": ["us-east-1", "us-west-2"]
        }
      }
    }
  ]
}
```

### Change Management

#### Change Request Process
1. **Planning Phase**
   - Document proposed changes
   - Assess impact and risks
   - Schedule maintenance window
   - Notify stakeholders

2. **Testing Phase**
   - Test changes in development environment
   - Validate rollback procedures
   - Review with team lead

3. **Implementation Phase**
   - Execute during maintenance window
   - Monitor for issues
   - Validate successful deployment
   - Update documentation

4. **Post-Implementation**
   - Confirm system stability
   - Update runbooks if needed
   - Conduct lessons learned review

#### Emergency Change Process
1. **Immediate Assessment** (5 minutes)
   - Identify scope and urgency
   - Notify team lead and stakeholders
   - Document issue and proposed solution

2. **Rapid Implementation** (15-30 minutes)
   - Execute emergency change
   - Monitor system stability
   - Document actions taken

3. **Post-Emergency Review** (within 24 hours)
   - Conduct root cause analysis
   - Update procedures to prevent recurrence
   - Schedule formal change if needed

This operations guide provides comprehensive procedures for cloud teams to successfully deploy, maintain, and scale the Quilt platform. Regular review and updates of these procedures ensure continued operational excellence.

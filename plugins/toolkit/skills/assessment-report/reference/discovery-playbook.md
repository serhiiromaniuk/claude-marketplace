# Discovery playbook (read-only)

Gather inventory + posture **without mutating anything**. Use only describe/list/get/read calls. Record evidence + a confidence flag per finding. Never read or print secrets/keys/tokens.

## Golden rules
- Read-only only. No create/update/delete, no restarts, no writes.
- Verify the *region* before concluding "empty" — resources may live elsewhere than the profile's default region (sweep a few regions).
- Prefer live evidence over Terraform/docs; mark anything not live-confirmed as Inferred.

## AWS (per account/profile, read-only)
```bash
aws sts get-caller-identity --profile P                       # confirm SSO/identity
# multi-region sweep for compute (don't trust the default region)
for R in eu-central-1 eu-north-1 us-east-1 eu-west-1; do
  echo "$R"; for s in "ecs list-clusters" "rds describe-db-instances" \
    "ec2 describe-instances" "elbv2 describe-load-balancers"; do
    aws $s --profile P --region $R --query 'length(@)' --output text 2>/dev/null; done; done
# posture probes
aws iam list-users --profile P --query 'Users[].UserName'                          # static users
aws iam list-attached-user-policies --profile P --user-name U                      # over-privilege
aws iam get-access-key-last-used --profile P --access-key-id AKIA…                 # key age/use
aws ec2 describe-security-groups --profile P --region R \
  --query 'SecurityGroups[?...0.0.0.0/0...]'                                        # open ingress (22/3389!)
aws ecs describe-services --profile P --region R --cluster C --services S \
  --query 'services[].[desiredCount,runningCount]'                                 # HA: task count
aws rds describe-db-instances --query 'DBInstances[].[MultiAZ,PubliclyAccessible,StorageEncrypted,BackupRetentionPeriod,DeletionProtection]'
aws wafv2 get-web-acl-for-resource --resource-arn <alb-arn>                         # WAF on public ALB?
aws cloudwatch describe-alarms --query 'length(MetricAlarms)'                       # monitoring depth
aws s3api get-public-access-block / get-bucket-encryption / get-bucket-versioning  # bucket posture
```
- **Cost actuals** (Cost Explorer, region us-east-1): `aws ce get-cost-and-usage --time-period Start=..,End=.. --granularity MONTHLY --metrics UnblendedCost [--group-by Type=DIMENSION,Key=SERVICE]`.
- **Backup/DR**: RDS `PreferredBackupWindow`, `LatestRestorableTime`, `describe-db-snapshots`; ElastiCache `SnapshotRetentionLimit`, `describe-replication-groups` (AutomaticFailover/MultiAZ). Distinguish **RPO** (data loss) from **RTO** (time to recover). Note `skip_final_snapshot` in TF.

## Hosts / CI (SSH, read-only)
```bash
ssh -o BatchMode=yes -o ConnectTimeout=8 user@host '...'   # BatchMode = never hang on a password
# versions/EOL, disk, RAM/swap, containers
hostname; . /etc/os-release; df -h /; free -h; docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}'
docker exec <runner> gitlab-runner --version ; docker exec <dind> docker --version
crontab -l                                                  # cleanup jobs
```
- Root-owned configs you can't read non-interactively → mark the finding **Inferred** and say so (don't guess silently). Ask the user to run a `sudo` read via `! …` if needed.
- Brute-force exposure: large `/var/log/btmp`, no fail2ban.

## Terraform / IaC
- Locate the repo locally first; clone only with the user's OK. Note last-commit date (staleness) and whether it's even a git repo (provenance).
- Compare **IaC to reality** — drift, duplicate/competing codebases, unpinned/floating image tags, `skip_final_snapshot`, default-VPC usage.

## Confluence / Jira (Atlassian MCP)
- `getConfluencePage` for runbooks/context; `searchConfluenceUsingCql` to find pages.
- The Rovo MCP can be **IP-allowlist blocked** ("permission to connect from this IP"). A `/mcp` reconnect sometimes lands on an allowed egress; otherwise read via the browser (user's own session) or ask an admin to allowlist the connector egress.

## Integrity statement (put in the report)
State plainly: discovery was read-only, no resource created/modified/deleted, no secrets read. It's both true and trust-building.

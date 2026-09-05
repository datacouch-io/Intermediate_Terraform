
Status: **tested** — every command, version string and error message below was run for real on
**2026-09-05** (macOS, Darwin 25.5.0, Apple Silicon) against a live AWS account in `us-east-1`.
Nothing here is illustrative.

Do this once, before Lab 1. It takes about 20 minutes, most of which is waiting for an AWS
account if you do not already have one.

---

## 1. What the course assumes you already know

This is the *intermediate* course. It assumes you have written at least a little HCL before and
have run `terraform apply` at least once. It does not assume you know what a backend is, how
state drift is detected, or how modules and workspaces relate to each other — those are the
course.

---

## 2. Software

| Requirement | Tested with | Notes |
|---|---|---|
| macOS or Linux | Darwin 25.5.0 (arm64) | Windows works via WSL2 |
| Terraform CLI | **v1.15.7** | 1.5.0+ is the floor; `import` blocks in Lab 3 need 1.5+ |
| AWS CLI v2 | **2.35.11** | used for cross-checks and for the Lab 3 drift step |
| A text editor | any | the HashiCorp Terraform extension for VS Code is worth installing |
| `curl` | system | Lab 4 uses it to prove the web server is live |

Install on macOS:

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform awscli
```

Confirm both:

```bash
terraform version
aws --version
```

**Expected output** (yours will differ in the patch numbers):

```
Terraform v1.15.7
on darwin_arm64

aws-cli/2.35.11 Python/3.14.5 Darwin/25.5.0 exe/arm64
```

> **Why the version floor matters:** Lab 3 uses `import` **blocks** (declarative import in HCL),
> which landed in Terraform 1.5. On 1.4 or earlier you can only use the older
> `terraform import` *command*. Lab 3 teaches both, but the block form will simply fail to parse
> on an old binary, and the error — a syntax error on a valid file — is confusing enough that it
> is worth avoiding.

---

## 3. AWS access

### 3.1 What you need

An AWS account where you are allowed to create and destroy EC2 instances, VPCs, security
groups, S3 buckets and a DynamoDB table. A personal sandbox account is ideal. A shared corporate
account with SCPs on it will fight you somewhere around Lab 8.

Minimum services touched across the nine labs:

| Service | Used in | Why |
|---|---|---|
| EC2 | Labs 1–8 | instances and security groups; no SSH keys are needed anywhere |
| VPC | Labs 4, 5 | a purpose-built network, not the default VPC |
| SSM Parameter Store | Labs 1, 2, 6 | **read-only, and only from the AWS CLI** — used to look up current AMI IDs for comparison. No Terraform configuration reads SSM. |
| S3 | Labs 8, 9 | remote state backend (Lab 8); static website hosting (Lab 9) |
| DynamoDB | Lab 8 | the classic state-locking table — which Terraform 1.15 now deprecates in favour of `use_lockfile`. Lab 8 covers both. |
| IAM | Lab 6 | one permission-denied scenario, shipped as a **reference artifact rather than an applied step** — see the root-credentials caveat below |

### 3.2 Configure credentials

```bash
aws configure
```

Then confirm they resolve:

```bash
aws sts get-caller-identity
```

**Expected output** — a JSON block with `UserId`, `Account` and `Arn`:

```json
{
    "UserId": "AIDA...",
    "Account": "<ACCOUNT_ID>",
    "Arn": "arn:aws:iam::<ACCOUNT_ID>:user/your-name"
}
```

If this errors, stop. Nothing in any lab can succeed until it does not.

> **Root-credentials caveat, from the authoring environment:** the account these labs were
> tested against was configured with **root user** credentials (`Arn` ended in `:root`). Every
> lab passed — but you should not do this, and Lab 6 says so explicitly: an IAM permission
> failure is one of its two induced errors, and **root cannot be denied by an IAM policy
> attached to itself**. If you are running with root credentials, Lab 6's IAM scenario will not
> reproduce for you, and the lab tells you what to do instead. Create an IAM user with
> `AdministratorAccess` for the course if you can.

### 3.3 Set a region — the single most common setup failure

This is the first thing that breaks, because `aws configure` will happily leave the region blank
and the AWS CLI mostly copes while Terraform does not.

```bash
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1
```

Put those two lines in your `~/.zshrc` or `~/.bashrc` for the duration of the course. Every lab
in this course uses **`us-east-1`**; if you use another region you must change the hardcoded AMI
ID in Lab 1 (Lab 2 fixes that problem properly, which is the point of Lab 2).

### 3.3b Set a provider plugin cache — do this before Lab 1

Each lab directory otherwise downloads its own copy of the AWS provider. Measured size of one
`.terraform/` directory during authoring: **789 MB**. Across nine labs that is slow, and it is
fragile — one download failed mid-transfer with `read: connection reset by peer`.

```bash
mkdir -p ~/.terraform.d/plugin-cache
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
```

Add that to your shell profile alongside `AWS_REGION`. Measured total after all of this course's
providers: **809 MB, shared once**, instead of 789 MB per directory.

> **Tested gotcha:** with no region set anywhere — not in `~/.aws/config`, not in the
> environment, not in the `provider` block — `terraform plan` fails with an error that names the
> provider block rather than your shell, which sends people editing the wrong file. This is the
> real output:
>
> ```
> Planning failed. Terraform encountered an error while generating this plan.
>
> Error: invalid AWS Region:
>
>   with provider["registry.terraform.io/hashicorp/aws"],
>   on main.tf line 1, in provider "aws":
>    1: provider "aws" {}
> ```
>
> Note the empty string after `invalid AWS Region:` — that blank is the whole diagnosis.

### 3.4 Confirm you have a default VPC

Labs 1, 2, 3, 7 and 8 place instances in your account's default VPC. Labs 4 and 5 build their
own. Check the default one exists:

```bash
aws ec2 describe-vpcs --filters Name=isDefault,Values=true \
  --query 'Vpcs[].{Id:VpcId,Cidr:CidrBlock}' --output table
aws ec2 describe-subnets --filters Name=default-for-az,Values=true --query 'length(Subnets)'
```

**Expected output** — one VPC and (in `us-east-1`) six subnets:

```
-------------------------------
|        DescribeVpcs         |
+------------------+----------+
|       Cidr       |    Id    |
+------------------+----------+
|  172.31.0.0/16   |  vpc-... |
+------------------+----------+
6
```

If `DescribeVpcs` returns an empty list, your account's default VPC was deleted. Recreate it
once with `aws ec2 create-default-vpc`, or plan to use Lab 4's explicit-VPC approach everywhere.

---

## 4. Cost and time

Real, measured numbers from the authoring run, not estimates from a blog post.

**Measured on-demand price**, from the AWS Pricing API on 2026-09-05:

```
t3.micro on-demand: 0.0104000000 per Hrs | $0.0104 per On Demand Linux t3.micro Instance Hour
```

These are the resources each lab **actually** created during the authoring run, not estimates:

| Lab | Peak billable resources | Cost if left running 1 hour |
|---|---|---|
| 1 | 1 × t3.micro | $0.0104 |
| 2 | 1 × t3.micro, briefly resized to t3.small | $0.0104 → $0.0208 |
| 3 | 1 × t3.micro + 1 security group (free) | $0.0104 |
| 4 | 1 × t3.micro + VPC, IGW, subnet, route table, 2 SG rules (all free) | $0.0104 |
| 5 | **1 × t3.micro (dev) + 2 × t3.small (prod)** — 27 resources across two environments | **$0.052** |
| 6 | 1 × t3.micro, briefly 2 while the conditional bastion is enabled | $0.0104 → $0.0208 |
| 7 | 2 × t3.micro + 1 × t3.small | $0.0416 |
| 8 | 3 × t3.micro, scaled to 5 + S3 bucket + DynamoDB (PAY_PER_REQUEST) | $0.0312 → $0.052 |
| 9 | S3 static website only — **no EC2 at all** | fractions of a cent |

**Lab 5 is the most expensive**, because it is the only one that deliberately runs two environments
simultaneously. Lab 9 is the cheapest by two orders of magnitude.

**Total if every lab is applied, verified and destroyed within its own session: well under
$1.00.** The entire authoring run — nine labs, every apply executed for real, several of them two or
three times over, plus a five-node fleet and two parallel environments — cost less than a cup of
coffee. The cost risk in this course is not the instance price,
it is **forgetting to run `terraform destroy`**. Every lab ends with a cleanup step for that
reason, and §6 below is the backstop.

> **Snapshot warning:** `$0.0104/hr` is the price the Pricing API returned on 2026-09-05 in
> `us-east-1`. Prices change and regions differ. Re-run the query in §7 rather than trusting this
> table a year from now.

Time: the nine labs total **615 minutes — 10 hours 15 minutes** of hands-on work (45+60+75+90+90+60+60+75+60),
which is what fills a two-day instructor-led course once discussion is allowed for.

---

## 5. Working directory layout

```bash
mkdir -p ~/terraform-course && cd ~/terraform-course
```

Each lab is a self-contained directory with its own state. That is deliberate: it means you can
start at Lab 5 on day two without having kept Lab 1 alive overnight, and it means a broken lab
never poisons the next one.

```
~/terraform-course/
  lab-1-first-project/
  lab-2-variables/
  lab-3-state-drift/
  ...
```

> **Never commit these to a public repository.** `terraform.tfstate` contains every attribute of
> every resource, in plaintext, including things that are secret in other configurations. Lab 8
> is where this stops being a warning and becomes a design problem you solve.

A `.gitignore` worth having from the start:

```bash
cat > ~/terraform-course/.gitignore << 'EOF'
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
crash.log
EOF
```

Note `*.tfvars` is ignored: Lab 2 puts values there, and in real projects that file is where
someone eventually puts a password.

---

## 6. The backstop — find and kill anything you forgot

Run this at the end of every day of the course. Every resource these labs create is tagged
`Course=intermediate-terraform`, precisely so this query works:

```bash
aws ec2 describe-instances \
  --filters Name=tag:Course,Values=intermediate-terraform \
            Name=instance-state-name,Values=running,pending,stopped \
  --query 'Reservations[].Instances[].{ID:InstanceId,Type:InstanceType,State:State.Name,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table
```

**Expected output at the end of a clean day: nothing at all.** Not an empty table — literally
zero bytes of output, and exit code 0. That is what a fully cleaned account looks like:

```
$ aws ec2 describe-instances --filters Name=tag:Course,Values=intermediate-terraform ...
$ echo $?
0
```

Anything listed is still billing you — go back to that lab's directory and run
`terraform destroy`. If the directory is gone but the instance is not, terminate it by ID:
`aws ec2 terminate-instances --instance-ids i-xxxxxxxx`.

---

## 7. Re-measuring the price yourself

```bash
aws pricing get-products --region us-east-1 --service-code AmazonEC2 \
 --filters 'Type=TERM_MATCH,Field=instanceType,Value=t3.micro' \
           'Type=TERM_MATCH,Field=regionCode,Value=us-east-1' \
           'Type=TERM_MATCH,Field=operatingSystem,Value=Linux' \
           'Type=TERM_MATCH,Field=tenancy,Value=Shared' \
           'Type=TERM_MATCH,Field=capacitystatus,Value=Used' \
           'Type=TERM_MATCH,Field=preInstalledSw,Value=NA' \
 --max-results 1 --output json | python3 -c "
import json,sys
p=json.loads(json.load(sys.stdin)['PriceList'][0])
for t in p['terms']['OnDemand'].values():
    for d in t['priceDimensions'].values():
        print(d['pricePerUnit']['USD'], 'per', d['unit'], '-', d['description'])
"
```

---

## 8. Lab index

| Lab | Title | Duration | You walk away with |
|---|---|---|---|
| 1 | [Environment Setup & First Terraform Project](lab-1-first-terraform-project.docx) | ~45 min | A real EC2 instance you created and destroyed |
| 2 | [Input Variables, Locals & Data Sources](lab-2-variables-locals-data-sources.docx) | ~60 min | One variable change re-shaping live infrastructure |
| 3 | [State Deep-Dive, Drift & Import](lab-3-state-drift-import.docx) | ~75 min | Drift caught by `plan`; an orphan resource adopted |
| 4 | [AWS Provider Deep-Dive: Multi-Resource Mini-App](lab-4-aws-provider-mini-app.docx) | ~90 min | A live web page on infrastructure you built |
| 5 | [Templates, Modules & Workspaces](lab-5-modules-workspaces.docx) | ~90 min | dev + prod from one module, side by side |
| 6 | [Error Handling & Debugging](lab-6-error-handling-debugging.docx) | ~60 min | A broken config debugged to a clean apply |
| 7 | [Built-in Functions & Data Manipulation](lab-7-functions-data-types.docx) | ~60 min | Resource names computed, never typed |
| 8 | [Loops, Backends & Scaling EC2](lab-8-loops-backends.docx) | ~75 min | A fleet from `count`; state living in S3 |
| 9 | [Capstone — Documentation Deep-Dive](lab-9-capstone-documentation-deep-dive.docx) | ~60 min | A resource type you deployed from docs alone |

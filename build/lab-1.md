# Lab 1 — Environment Setup & First Terraform Project

**Maps to:** *Setting up Learning Environments; Terraform Project (files, HCL, types, resources, commands, `terraform init`)*
**Duration:** ~45 minutes
**Status:** Tested end-to-end on 2026-09-05 (macOS Darwin 25.5.0, Terraform v1.15.7, AWS provider
v6.63.0) against a live AWS account in `us-east-1`. Every command output, instance ID, timing and
error message in this document came from a real run.

Prerequisite: [`00-shared-setup.md`](00-shared-setup.docx) completed.

---

## 1. Lab Overview & Objectives

You are going to write one file, run three commands, and end up with a real EC2 instance running
in your AWS account — one you can find in the console, ping from the CLI, and destroy again in
thirty seconds.

That is deliberately a small amount of infrastructure. The point of this lab is not the instance;
it is the **loop**: config → `init` → `plan` → `apply` → state → `destroy`. Every other lab in
this course is that same loop with more interesting things inside it. If the loop is not solid
here, nothing later will be.

**Learning objectives — by the end of this lab you will be able to:**

1. Write a minimal but *correct* Terraform project: a `terraform` block with pinned provider
   constraints, a `provider` block, a `resource`, and `output`s.
2. Explain what each of `init`, `plan` and `apply` actually does — specifically, which of them
   talk to AWS and which do not.
3. Read an execution plan, including what `(known after apply)` means and why almost every
   attribute shows it on a first run.
4. Prove from outside Terraform that the resource is real, and prove from inside Terraform that
   your configuration and reality still agree.

> **The most surprising measured result in this lab:** the validation suite at §5 has six checks.
> After someone added a single tag to the instance through the AWS console, **five of the six
> still passed** — the instance was still running, still correctly named, still had a valid public
> IP. Only the sixth check, `terraform plan -detailed-exitcode`, caught it. "The apply succeeded"
> and "the infrastructure matches the configuration" are different claims, and only one of them is
> worth anything the day after.

---

## 2. Prerequisites & Environment Setup

### 2.1 Software

| Requirement | Tested with |
|---|---|
| Terraform CLI | v1.15.7 (`darwin_arm64`) |
| AWS CLI v2 | 2.35.11 |
| AWS credentials | valid, with EC2 create/describe/terminate rights |

### 2.2 Region

Every command in this lab assumes `us-east-1`. Export it before you start:

```bash
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1
```

### 2.3 Cost and time

| | |
|---|---|
| Resources created | 1 × `t3.micro` EC2 instance |
| Measured price | **$0.0104 per instance-hour** (AWS Pricing API, `us-east-1`, 2026-09-05) |
| Measured create time | **18 seconds** |
| Measured destroy time | **22–32 seconds** across three runs |
| Realistic cost of this lab | **under $0.02** if you destroy at the end |
| Hands-on time | ~45 minutes |

The instance is not free-tier-guaranteed — `t3.micro` is free-tier eligible only for the first 12
months of a new account, and only up to 750 hours/month. Assume you are paying, and destroy.

### 2.4 Create the working directory

```bash
mkdir -p ~/terraform-course/lab-1-first-project && cd ~/terraform-course/lab-1-first-project
```

---

## 3. Architecture

![Lab 1 architecture: a single main.tf flows through terraform init, plan and apply into a real EC2 instance and a local state file, is verified from both inside and outside Terraform, and is then destroyed back to zero](artifacts/lab-1/diagrams/lab-1-architecture.png)

*Vector version: [`lab-1-architecture.svg`](artifacts/lab-1/diagrams/lab-1-architecture.svg)*

The same flow, linear, if you prefer it in text:

```
main.tf                       ← the only file you write
  terraform { required_providers { aws ~> 6.0 } }
  provider  "aws"      { region = "us-east-1" }
  resource  "aws_instance" "lab" { ami, instance_type, tags }
  output    instance_id, instance_public_ip
    │
    ├── terraform init ──────► .terraform/            (provider binary, 
    │                          .terraform.lock.hcl     downloaded)
    │                          NO AWS calls, NO state yet
    │
    ├── terraform plan ──────► "Plan: 1 to add, 0 to change, 0 to destroy"
    │                          reads config + state; nothing is created
    │
    ├── terraform apply ─────► EC2 RunInstances  ───► i-09b4c73740225e37c   (18s)
    │                          terraform.tfstate  ───► config ↔ real-ID map
    │                          outputs            ───► 54.145.168.39
    │
    ├── verification
    │     inside  Terraform:  terraform state list  → aws_instance.lab
    │     outside Terraform:  aws ec2 describe-instances → State: running
    │     agreement:          terraform plan -detailed-exitcode → exit 0
    │
    └── terraform destroy ───► "Resources: 1 destroyed"   (22s), billing stops
```

**Three things worth understanding before you run anything:**

- **`init` makes no AWS calls.** It resolves and downloads the provider plugin and writes a lock
  file. You can run it with no credentials at all. People frequently believe `init` "connects to
  AWS"; it does not, which is why a credentials problem does not surface until `plan`.
- **`plan` creates nothing, but it is not free of side effects on your understanding of state.**
  It reads your config and your state, and refreshes state from AWS. On a first run there is no
  state, so almost everything is `(known after apply)`.
- **State is the whole trick.** `terraform.tfstate` is the map from `aws_instance.lab` (your name)
  to `i-09b4c73740225e37c` (AWS's name). Delete it and Terraform forgets it owns the instance —
  the instance keeps running and keeps billing. That is Lab 3's subject.

---

## 4. Step-by-Step Instructions

### Step 1 — Write `main.tf`

**Why:** Terraform has no project scaffolding command — no `terraform new`. A project is simply a
directory containing `.tf` files, and Terraform loads *all* of them and treats them as one merged
configuration. Filenames are a convention for humans, not a rule. We start with everything in one
file so nothing is hidden, and split it up in Lab 2.

```bash
cat > main.tf << 'EOF'
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "lab" {
  ami           = "ami-081b0a6eac00b4f53" # Amazon Linux 2023, us-east-1
  instance_type = "t3.micro"

  tags = {
    Name   = "tf-lab1-first-instance"
    Lab    = "1"
    Course = "intermediate-terraform"
  }
}

output "instance_id" {
  description = "The EC2 instance ID Terraform created."
  value       = aws_instance.lab.id
}

output "instance_public_ip" {
  description = "Public IPv4 address assigned to the instance."
  value       = aws_instance.lab.public_ip
}
EOF
```

Read what you just wrote, block by block:

| Block | What it is | Why it is here |
|---|---|---|
| `terraform { required_version }` | settings for Terraform itself | fails fast on an old CLI instead of throwing a confusing syntax error |
| `required_providers` | which plugins, from where, at what version | `~> 6.0` means "≥ 6.0, < 7.0" — you get patches and features, never a breaking major |
| `provider "aws"` | configuration for one plugin | region here; credentials come from the environment, never from this file |
| `resource "aws_instance" "lab"` | one real thing to create | `aws_instance` is the **type** (fixed by the provider), `lab` is the **local name** (yours) |
| `output` | a value to surface after apply | how you get data out of Terraform and into your terminal or another module |

> **Never put credentials in the `provider` block.** It accepts `access_key` and `secret_key`
> arguments, and every leaked-secrets incident involving Terraform starts with someone using them.
> The provider reads the same environment variables and `~/.aws/credentials` file the AWS CLI does.

> **The hardcoded AMI is a deliberate flaw.** `ami-081b0a6eac00b4f53` is Amazon Linux 2023 in
> `us-east-1` **on 2026-09-05**. AMI IDs are region-specific *and* change whenever AWS publishes a
> new image. This config is therefore already slightly wrong, and will be more wrong next month.
> Lab 2 fixes it properly with a data source. Notice the problem now so the fix means something.

### Step 2 — `terraform init`

**Why:** Terraform ships with no providers built in. `init` reads `required_providers`, resolves a
version that satisfies your constraint, downloads it, and records the exact version and checksums
in a lock file so that everyone on your team gets the identical plugin.

```bash
terraform init
```

**Expected output** (real, from the authoring run):

```
Initializing provider plugins found in the configuration...
- Finding hashicorp/aws versions matching "~> 6.0"...
- Installing hashicorp/aws v6.63.0...
- Installed hashicorp/aws v6.63.0 (signed by HashiCorp)

Initializing the backend...

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!
```

Look at what appeared:

```bash
ls -la
```

- `.terraform/` — the downloaded provider binary. Large, machine-specific, **git-ignore it**.
- `.terraform.lock.hcl` — the resolved version and its checksums. Small, portable, **commit it**.

> **Tested detail:** the constraint `~> 6.0` resolved to **v6.63.0** on 2026-09-05. Yours may
> resolve higher — that is the constraint working as designed. If you want the exact provider this
> lab was tested with, the lock file is how you'd pin it, not the version constraint.

> **`init` needs no AWS credentials.** Prove it to yourself if you like: `rm -rf .terraform &&
> env -u AWS_ACCESS_KEY_ID -u AWS_PROFILE terraform init` still succeeds. It is a package-manager
> step, not a cloud step.

### Step 3 — `terraform plan`

**Why:** `plan` is the safety mechanism that distinguishes Terraform from a shell script. It
computes the difference between what you declared, what it has recorded in state, and what exists
in AWS — and shows you the result *before* anything changes. In a real team this output is what
gets reviewed in a pull request.

```bash
terraform plan
```

**Expected output** — abridged from the real run; the full capture is in
[`artifacts/lab-1/output/02-plan.txt`](artifacts/lab-1/output/02-plan.txt):

```
Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_instance.lab will be created
  + resource "aws_instance" "lab" {
      + ami                                  = "ami-081b0a6eac00b4f53"
      + arn                                  = (known after apply)
      + associate_public_ip_address          = (known after apply)
      + availability_zone                    = (known after apply)
      + id                                   = (known after apply)
      + instance_state                       = (known after apply)
      + instance_type                        = "t3.micro"
      + private_ip                           = (known after apply)
      + public_ip                            = (known after apply)
      + region                               = "us-east-1"
      + subnet_id                            = (known after apply)
      + tags                                 = {
          + "Course" = "intermediate-terraform"
          + "Lab"    = "1"
          + "Name"   = "tf-lab1-first-instance"
        }
      ...
    }

Plan: 1 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + instance_id        = (known after apply)
  + instance_public_ip = (known after apply)

─────────────────────────────────────────────────────────────────────────────

Note: You didn't use the -out option to save this plan, so Terraform can't
guarantee to take exactly these actions if you run "terraform apply" now.
```

**Read the plan properly — this is the skill:**

- **`Plan: 1 to add, 0 to change, 0 to destroy.`** is the line to read first, and in a real
  change, the *only* number that matters is `to destroy`. Train yourself now.
- **`(known after apply)`** means "AWS decides this, not you". You did not choose the instance ID,
  the AZ, the subnet or the public IP, so Terraform cannot show them yet. On a first apply, most
  attributes look like this. It is not a warning.
- **`+ region = "us-east-1"`** appearing as a *resource attribute* is new in AWS provider v6 —
  every resource now carries a `region` argument that defaults to the provider's. In v5 and
  earlier this line does not appear. If you are following an older tutorial, this is why your
  output has an extra line.
- **The closing `Note:`** is telling you this plan is advisory. `terraform apply` will recompute
  it. To guarantee that what you reviewed is exactly what runs, use `terraform plan -out=tfplan`
  then `terraform apply tfplan` — which is what CI pipelines do.

Nothing has been created. Confirm it:

```bash
ls terraform.tfstate 2>&1
```

**Expected output:** `ls: terraform.tfstate: No such file or directory` — `plan` writes no state.

### Step 4 — `terraform apply`

**Why:** This is the step that costs money and creates something you must remember to remove.
Everything before it was rehearsal.

```bash
terraform apply
```

Terraform re-prints the plan and stops for confirmation. Type `yes`.

**Expected output** (tail of the real run):

```
Plan: 1 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + instance_id        = (known after apply)
  + instance_public_ip = (known after apply)
aws_instance.lab: Creating...
aws_instance.lab: Still creating... [00m10s elapsed]
aws_instance.lab: Creation complete after 18s [id=i-063bf80b54cbdd3d7]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

instance_id = "i-063bf80b54cbdd3d7"
instance_public_ip = "52.23.237.145"
```

**Your instance ID and IP will differ. That is the point** — those are the values AWS chose, which
is exactly why they were `(known after apply)` a moment ago.

Measured create time in the authoring run: **18 seconds**.

> The `-auto-approve` flag skips the confirmation prompt. It is correct in CI and a bad habit at a
> terminal. This document uses it only because the authoring runs were scripted.

### Step 5 — Prove it is real, from both sides

**Why:** A green "Apply complete!" tells you the API call returned 200. It does not tell you the
instance is running, or that AWS recorded what you asked for. Verify from inside Terraform *and*
from outside it — those are genuinely different questions.

**From inside Terraform:**

```bash
terraform state list
terraform output
```

**Expected output:**

```
aws_instance.lab

instance_id = "i-063bf80b54cbdd3d7"
instance_public_ip = "52.23.237.145"
```

`terraform show` prints every recorded attribute. The interesting ones:

```bash
terraform show | grep -E '^\s+(id|ami|instance_type|instance_state|public_ip|private_ip|availability_zone|arn)\s+='
```

**Expected output:**

```
    ami                                  = "ami-081b0a6eac00b4f53"
    arn                                  = "arn:aws:ec2:us-east-1:<ACCOUNT_ID>:instance/i-063bf80b54cbdd3d7"
    availability_zone                    = "us-east-1d"
    id                                   = "i-063bf80b54cbdd3d7"
    instance_state                       = "running"
    instance_type                        = "t3.micro"
    private_ip                           = "172.31.18.61"
    public_ip                            = "52.23.237.145"
```

Note `availability_zone = "us-east-1d"` — you never specified an AZ. AWS picked one, and Terraform
recorded the choice. That recorded value is what makes drift detectable later.

**From outside Terraform** — this is the part that actually proves the infrastructure exists,
because it does not consult Terraform's state at all:

```bash
aws ec2 describe-instances --instance-ids $(terraform output -raw instance_id) \
  --query 'Reservations[0].Instances[0].{ID:InstanceId,State:State.Name,Type:InstanceType,AZ:Placement.AvailabilityZone,PublicIP:PublicIpAddress,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table
```

**Expected output:**

```
----------------------------------------
|           DescribeInstances          |
+-----------+--------------------------+
|  AZ       |  us-east-1d              |
|  ID       |  i-063bf80b54cbdd3d7     |
|  Name     |  tf-lab1-first-instance  |
|  PublicIP |  52.23.237.145           |
|  State    |  running                 |
|  Type     |  t3.micro                |
+-----------+--------------------------+
```

**And from the AWS Console**, which is the version to show a sceptical colleague: EC2 → Instances,
filter by the tag `Course = intermediate-terraform`. Your instance is there, with the name you
declared in HCL.

### Step 6 — Look inside the state file

**Why:** State is the single concept that most distinguishes Terraform from a deployment script,
and the fastest way to demystify it is to read it. It is only JSON.

```bash
python3 -m json.tool terraform.tfstate | head -30
grep -c '"type"' terraform.tfstate
```

Things to notice:

- `"serial"` increments on every state-changing operation — it is how Terraform detects that
  someone else wrote the state after you read it.
- `"lineage"` is a UUID identifying *this* state's history. Two states with different lineages are
  not the same infrastructure, even if they describe identical resources.
- Under `resources[0].instances[0].attributes` is a full snapshot of every attribute AWS returned.
  **This is a plaintext copy of your infrastructure.** Here it is harmless. In a config with an RDS
  password it is not, and no amount of `sensitive = true` in your HCL encrypts it on disk. That is
  the argument for the remote backend you build in Lab 8.

> **Do not edit this file by hand.** There are `terraform state` subcommands for every legitimate
> manipulation. Hand-editing is how people end up with a `serial` that lies.

### Step 7 — Do it again yourself, in a second region, unassisted

**Why:** One guided pass is not skill. This lab handed you a working AMI ID; the version of this
task you will meet in real life does not, and the reason it does not is the exact flaw this lab
deliberately shipped with.

**Your task.** In a **new directory** (`lab-1-practice/`), deploy one `t3.micro` Amazon Linux 2023
instance into **`us-west-2`** instead of `us-east-1`. You may not reuse `ami-081b0a6eac00b4f53` —
it does not exist in `us-west-2`, and if you try it you will get a real error worth reading.

**You get the acceptance criteria and nothing else:**

- `terraform apply` succeeds in `us-west-2` with no hardcoded AMI copied from another region's
  console.
- `aws ec2 describe-instances --region us-west-2` shows the instance `running`, tagged
  `Course=intermediate-terraform`.
- Your config contains no `access_key` or `secret_key`.
- `terraform plan -detailed-exitcode` exits `0` immediately after the apply.
- `terraform destroy` removes it, and the §6 backstop query in the shared setup returns nothing
  for **both** regions.

**Done when** you can state, in one sentence, *how you obtained the correct AMI ID for
`us-west-2`* and *why that method will still be right in six months when this document's
hardcoded ID is wrong.*

No commands are given here. Steps 1–6 have them; the exercise is discovering that "the AMI ID" is
not a constant, which is the problem Lab 2 opens with.

---

## 5. Validation / Verification

Save this as `validate.sh` in your lab directory and run it after `terraform apply`. It is also
committed at [`lab-1-first-project/validate.sh`](lab-1-first-project/validate.sh).

```bash
cat > validate.sh << 'EOF'
#!/usr/bin/env bash
# Lab 1 validation. Run from the lab-1-first-project directory after `terraform apply`.
set -uo pipefail
fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fail=1; fi }

ID=$(terraform output -raw instance_id 2>/dev/null)
IP=$(terraform output -raw instance_public_ip 2>/dev/null)

# 1. Terraform believes it manages exactly one resource.
check "state holds exactly 1 resource" "$(terraform state list | wc -l | tr -d ' ')" "1"

# 2. That resource is the instance we named.
check "the managed resource is aws_instance.lab" "$(terraform state list)" "aws_instance.lab"

# 3. AWS agrees the instance exists and is running.
check "AWS reports the instance running" \
  "$(aws ec2 describe-instances --instance-ids "$ID" --query 'Reservations[0].Instances[0].State.Name' --output text)" \
  "running"

# 4. The tag AWS holds matches the tag we declared.
check "Name tag round-tripped to AWS" \
  "$(aws ec2 describe-instances --instance-ids "$ID" --query "Reservations[0].Instances[0].Tags[?Key=='Name']|[0].Value" --output text)" \
  "tf-lab1-first-instance"

# 5. The output is a routable public IPv4, not empty and not a private range.
if [[ "$IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && [[ ! "$IP" =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.) ]]; then
  echo "PASS  public IP is a routable IPv4 ($IP)"
else
  echo "FAIL  public IP looks wrong: '$IP'"; fail=1
fi

# 6. THE ONE THE HAPPY PATH MISSES: config and reality still agree.
terraform plan -detailed-exitcode -no-color > /dev/null 2>&1
case $? in
  0) echo "PASS  no drift: plan reports zero changes" ;;
  2) echo "FAIL  DRIFT: plan wants to change something — run 'terraform plan' to see what"; fail=1 ;;
  *) echo "FAIL  plan errored"; fail=1 ;;
esac

echo
[ $fail -eq 0 ] && echo "Lab 1 validation: ALL CHECKS PASSED" || echo "Lab 1 validation: FAILURES ABOVE"
exit $fail
EOF
chmod +x validate.sh
./validate.sh
```

**Actual output from the authoring run** (instance `i-09b4c73740225e37c`, exit code `0`):

```
PASS  state holds exactly 1 resource
PASS  the managed resource is aws_instance.lab
PASS  AWS reports the instance running
PASS  Name tag round-tripped to AWS
PASS  public IP is a routable IPv4 (54.145.168.39)
PASS  no drift: plan reports zero changes

Lab 1 validation: ALL CHECKS PASSED
```
![Terminal showing all six Lab 1 validation checks passing, ending with 'Lab 1 validation: ALL CHECKS PASSED'](artifacts/lab-1/screenshots/lab-1-validate.png)

### Why check 6 is the only one that earns its place

Checks 1–5 all interrogate the *happy path*: did the thing get made, is it running, is it named
right. Check 6 asks a different question — **does the configuration still describe reality?**

This was not a theoretical concern; it was measured. With the instance still running, a single tag
was added through the AWS API, exactly as a colleague clicking around the console would:

```bash
aws ec2 create-tags --resources $(terraform output -raw instance_id) \
  --tags Key=Owner,Value=someone-in-the-console
./validate.sh
```

**Actual output — five passes and one failure, exit code `1`:**

```
PASS  state holds exactly 1 resource
PASS  the managed resource is aws_instance.lab
PASS  AWS reports the instance running
PASS  Name tag round-tripped to AWS
PASS  public IP is a routable IPv4 (54.145.168.39)
FAIL  DRIFT: plan wants to change something — run 'terraform plan' to see what

Lab 1 validation: FAILURES ABOVE
```
![The same validation run after a single tag was changed in the AWS console: five checks still pass in green, only the drift check fails in red](artifacts/lab-1/screenshots/lab-1-validate-drift.png)

`terraform plan` then names the culprit precisely:

```
  # aws_instance.lab will be updated in-place
  ~ resource "aws_instance" "lab" {
        id                                   = "i-09b4c73740225e37c"
      ~ tags                                 = {
            "Course" = "intermediate-terraform"
            "Lab"    = "1"
            "Name"   = "tf-lab1-first-instance"
          - "Owner"  = "someone-in-the-console" -> null
        }
      ~ tags_all                             = {
          - "Owner"  = "someone-in-the-console" -> null
            # (3 unchanged elements hidden)
        }
        # (39 unchanged attributes hidden)
```

Read the `- "Owner" = "someone-in-the-console" -> null` line carefully. Terraform is not offering
to *keep* the console change — it is proposing to **delete** it, because the configuration is the
source of truth and the configuration has never heard of `Owner`. That asymmetry is the entire
subject of Lab 3.

> `-detailed-exitcode` is the flag that makes `plan` usable in automation: `0` = no changes,
> `1` = error, `2` = changes pending. A nightly job running `terraform plan -detailed-exitcode` and
> alerting on `2` is a drift detector you can build this afternoon.

---

## 6. Troubleshooting Tips

Each of these was hit for real while building this lab.

**`Error: invalid AWS Region:` with nothing after the colon**

```
Error: invalid AWS Region:

  with provider["registry.terraform.io/hashicorp/aws"],
  on main.tf line 1, in provider "aws":
   1: provider "aws" {}
```

The error names your `provider` block, which sends most people editing `main.tf`. The actual cause
is that no region is set *anywhere* — not in the block, not in `~/.aws/config`, not in the
environment. The empty string after the colon is the diagnosis. Fix with
`export AWS_REGION=us-east-1`, or by hardcoding `region` in the provider block as this lab does.

**`init` succeeds but `plan` fails with a credentials error**

Expected, not a bug. `init` is a plugin download and never authenticates. Credentials are first
exercised by `plan`. Confirm them independently with `aws sts get-caller-identity` before blaming
Terraform.

**The plan shows a `region` attribute you have never seen before**

`+ region = "us-east-1"` inside the resource body is AWS provider **v6** behaviour — every
resource gained a per-resource `region` override. Tutorials written against v5 will not show it.
Nothing is wrong.

**`InvalidAMIID.NotFound` when you change region**

AMI IDs are region-scoped. `ami-081b0a6eac00b4f53` exists in `us-east-1` and nowhere else. This is
the failure the Step 7 practice task is built around, and the reason Lab 2 replaces the hardcoded
ID with a data source.

**`terraform destroy` says "Destroy complete! Resources: 0 destroyed"**

Terraform is only ever aware of what is in *this directory's* state. If you ran `apply` in a
different directory, or deleted `terraform.tfstate`, the instance is still running and still
billing. Fall back to the tag-based backstop query in
[`00-shared-setup.md` §6](00-shared-setup.docx) and terminate by instance ID.

**Apply hangs at `Still creating...` for minutes**

18 seconds is normal for `t3.micro`. Several minutes usually means a capacity or quota problem in
the chosen AZ, and it will eventually surface as a real API error — let it fail and read the
message rather than pressing Ctrl-C, which risks losing the record of a resource that was in fact
created.

---

## 7. Cleanup Steps

**Destroy the instance. This is not optional — it is the only thing in this lab that costs money.**

```bash
terraform destroy
```

Type `yes`. **Expected output:**

```
aws_instance.lab: Destroying... [id=i-063bf80b54cbdd3d7]
aws_instance.lab: Still destroying... [id=i-063bf80b54cbdd3d7, 00m10s elapsed]
aws_instance.lab: Still destroying... [id=i-063bf80b54cbdd3d7, 00m30s elapsed]
aws_instance.lab: Destruction complete after 32s

Destroy complete! Resources: 1 destroyed.
```

Measured destroy time across three authoring runs: **22s, 32s, 32s**.

Confirm nothing survived:

```bash
aws ec2 describe-instances \
  --filters Name=tag:Course,Values=intermediate-terraform \
            Name=instance-state-name,Values=running,pending,stopped \
  --query 'Reservations[].Instances[].InstanceId' --output text
```

**Expected output: nothing at all** — zero bytes, exit code 0.

**Keep these, and here is why:**

| Keep | Why |
|---|---|
| `main.tf` | Lab 2 refactors this exact file. Do not delete it. |
| `.terraform.lock.hcl` | Records that this lab ran against AWS provider v6.63.0. It is your reproducibility record and belongs in version control. |
| `terraform.tfstate` | After destroy it still exists, now holding zero resources but retaining `serial` and `lineage` (measured after the authoring run: `"serial": 8`, `"resources": []`). Lab 3 reads this file. |
| `validate.sh` | Later labs extend the same pattern. |

**Delete `.terraform/`** if you want the disk space back — measured at **789 MB** in the authoring
run, essentially all of it the AWS provider binary. `terraform init` re-creates it in seconds.

---

## Optional extensions

1. **Make the plan binding.** Re-run the lab with `terraform plan -out=tfplan` followed by
   `terraform apply tfplan`, and observe that apply no longer prompts for confirmation — it has
   already been given an approved plan. Then try modifying `main.tf` between the two commands and
   watch Terraform refuse the stale plan. This is exactly how a CI pipeline is structured.

2. **Break the version constraint on purpose.** Change `version = "~> 6.0"` to `"~> 5.0"` and run
   `terraform init -upgrade`. Note which provider version resolves, then run `terraform plan` and
   find the `region` attribute missing from the output. You have just reproduced the difference
   between this document and every v5-era tutorial you will find online.

3. **Delete the state file and feel the consequence.** With the instance running, `mv
   terraform.tfstate /tmp/`, then run `terraform plan`. Terraform proposes to create a *second*
   instance, because it no longer knows the first exists. Restore the file with `mv` and confirm
   the plan goes quiet. (Do this before `destroy`, not after — and do not skip restoring it.)

4. **Build the drift detector.** Wrap `terraform plan -detailed-exitcode` in a cron job or CI
   scheduled workflow that alerts on exit code 2. Ten lines of YAML, and it catches every console
   change anyone on your team makes.

5. **Re-measure the price.** The `$0.0104/hr` in §2.3 is a snapshot from 2026-09-05. Re-run the
   Pricing API query in [`00-shared-setup.md` §7](00-shared-setup.docx) for your own region and check
   whether this document's cost table is still true.

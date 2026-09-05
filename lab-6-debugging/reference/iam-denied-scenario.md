# Reference artifact: the IAM permission error — NOT applied during authoring

## Why this is a reference rather than a tested step

The course outline lists "bad IAM permission" as one of Lab 6's two induced provider errors. It is
**not** demonstrated with real output in the lab document, and the reason is worth stating plainly:

> The AWS account these labs were authored against was configured with **root user credentials**
> (`arn:aws:iam::<ACCOUNT_ID>:root`). **The root user cannot be restricted by an IAM policy attached
> to itself.** Attaching a deny policy to root has no effect; only an AWS Organizations Service
> Control Policy can constrain a root user, and applying an SCP means changing the customer's live
> organisation — which is not something a lab should do.

Everything else in Lab 6 was executed for real. This one control could not be, so it ships as an
artifact you can apply yourself in an account with a scoped IAM identity, rather than as invented
console output.

## How to reproduce it in your own account

You need an IAM **user or role** (not root) whose permissions you can change.

### 1. Attach a deny policy to the identity Terraform uses

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyLargeInstanceLaunch",
      "Effect": "Deny",
      "Action": "ec2:RunInstances",
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": {
        "StringNotEquals": {
          "ec2:InstanceType": ["t3.micro", "t3.small"]
        }
      }
    }
  ]
}
```

```bash
aws iam put-user-policy \
  --user-name <your-terraform-user> \
  --policy-name DenyLargeInstanceLaunch \
  --policy-document file://deny-large-instances.json
```

### 2. Ask Terraform for something the policy forbids

```hcl
resource "aws_instance" "app" {
  ami           = data.aws_ami.al2023.id
  instance_type = "t3.large" # denied by the policy above
}
```

### 3. What you will see

`terraform plan` **succeeds** — the plan does not attempt the API call. `terraform apply` fails with
an `UnauthorizedOperation` error of this shape:

```
Error: creating EC2 Instance: operation error EC2: RunInstances, https response error
StatusCode: 403, RequestID: ..., api error UnauthorizedOperation: You are not authorized to
perform this operation. User: arn:aws:iam::<ACCOUNT_ID>:user/<name> is not authorized to
perform: ec2:RunInstances on resource: arn:aws:ec2:us-east-1:<ACCOUNT_ID>:instance/* with an
explicit deny in an identity-based policy.
```

**The exact wording above is reconstructed from the AWS API contract, not captured from a run in
this account.** Treat the shape as indicative and read your own error rather than matching this
string.

### 4. What makes this error class distinctive

| | |
|---|---|
| Surfaces at | `apply` only — never `plan` |
| HTTP status | **403**, versus 400 for the malformed-input errors Lab 6 does demonstrate |
| Names | the IAM principal, the action, and whether the deny was explicit |
| Fix lives in | IAM, not in your Terraform configuration |

That last row is the teaching point. Every other error in Lab 6 is fixed by editing HCL. This one is
not: the configuration is correct and the credentials are wrong. Recognising which of the two you
are looking at is the actual skill, and the `403` versus `400` distinction is the fastest signal.

### 5. Clean up

```bash
aws iam delete-user-policy --user-name <your-terraform-user> --policy-name DenyLargeInstanceLaunch
```

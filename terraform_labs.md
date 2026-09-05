# Hands-On Labs — Intermediate Terraform (2-Day Instructor-Led Course)

Design principle: every lab produces something the participant can **see running/deployed in AWS**, or a **visible before/after state** (drift detected, error fixed, state changed) — not just completed steps.

---

## Lab 1 — Environment Setup & First Terraform Project
**Maps to:** Setting up Learning Environments; Terraform Project (files, HCL, types, resources, commands, `terraform init`)
**Duration:** ~45 min

**What needs to be built:**
- A pre-configured sandbox AWS account/IAM role and local CLI environment for each participant.
- A guided starter `.tf` file defining a single AWS resource (e.g., one EC2 instance).
- Walkthrough of `terraform init` → `terraform plan` → `terraform apply`.

**Visible end result:** A **real EC2 instance running in their AWS console**, confirmed by `terraform show` and by finding the instance in the AWS Console — their first deployed infrastructure.

---

## Lab 2 — Input Variables, Locals & Data Sources
**Maps to:** Extending Your Project (Input Variables, Locals, Data Sources, Local-Exec/Local-Remote/Null)
**Duration:** ~60 min

**What needs to be built:**
- Refactor Lab 1's hardcoded config into `variables.tf` + a `terraform.tfvars` file.
- Add a `locals` block computing a derived value (e.g., a naming convention).
- Add a `data` source (e.g., `aws_ami`) to dynamically fetch the latest AMI instead of hardcoding one.
- A `null_resource` with `local-exec` to run a post-deploy script (e.g., write the instance IP to a local file).

**Visible end result:** Participants **change one variable value and re-apply**, and watch the instance type/AMI/name change accordingly without touching the main config — plus a local file on their machine populated by the `local-exec` provisioner, proving the null_resource executed.

---

## Lab 3 — State Deep-Dive, Drift & Import
**Maps to:** How Terraform Works (State, Extracting Data from Statefile, Computing/Executing Plans); Configuration Drift, Drift Use Cases, Refresh Command, Importing Existing Resources
**Duration:** ~75 min

**What needs to be built:**
- A deployed resource from Lab 1/2 to inspect with `terraform state list` / `terraform state show`.
- A guided "drift" scenario: participants (or an instructor script) manually change a tag or setting on the resource **directly in the AWS Console**, bypassing Terraform.
- A separately pre-existing AWS resource (created outside Terraform, e.g., via console or CLI) for participants to `terraform import`.

**Visible end result:** Running `terraform plan` **visibly detects and displays the drift** they just caused manually (e.g., "tag will be reverted"). Then, after `terraform import`, the previously-unmanaged resource **shows up in `terraform state list`** and a subsequent `plan` shows no unexpected changes — proof it's now correctly tracked.

---

## Lab 4 — AWS Provider Deep-Dive: Multi-Resource Mini-App
**Maps to:** Providers and the AWS Provider (Provider Overview, The AWS Provider)
**Duration:** ~90 min

**What needs to be built:**
- A starter task requiring multiple interrelated AWS resources: VPC, subnet, security group, and an EC2 instance running a simple web server (via user-data script).
- Provider version constraints/config participants must set correctly for it to apply cleanly.

**Visible end result:** Participants **open a browser and hit the public IP of their deployed EC2 instance**, seeing a live web page served from infrastructure they just built — a fully working mini-application, not just isolated resources.

---

## Lab 5 — Templates, Modules & Workspaces (Reuse Patterns)
**Maps to:** Templates; Reuse Patterns in Terraform (Workspaces, Outputs, Modules — local and external/GitHub); Nested Directory Modules
**Duration:** ~90 min

**What needs to be built:**
- A reusable local module (e.g., a "web-server" module with input variables and outputs) built from Lab 4's mini-app.
- Two Terraform workspaces (`dev` and `prod`) each calling the same module with different variable values (e.g., different instance sizes/counts).
- A task to pull in and use one external module from a public GitHub repo.

**Visible end result:** Participants run `terraform workspace list` and see **two independently deployed environments (dev and prod) from the exact same module code**, each visible as separate, distinct running resources in AWS — proof the module is genuinely reusable, not copy-pasted.

---

## Lab 6 — Error Handling & Debugging
**Maps to:** Error Handling and Debugging in Terraform (Terraform vs. Provider errors, Pre-Induced Errors, dealing with conditional resource output)
**Duration:** ~60 min

**What needs to be built:**
- A deliberately broken `.tf` configuration containing at least one Terraform-syntax error and one AWS-provider-level error (e.g., invalid AMI ID, bad IAM permission).
- A conditional resource (created via `count = var.enabled ? 1 : 0`) whose output reference breaks if referenced incorrectly, requiring participants to fix the output syntax.
- Guidance on enabling `TF_LOG` for debugging.

**Visible end result:** Participants go from a **failing `terraform apply` (with real, readable error output)** to a **clean, successful apply** — the debug log trail and the before/after apply output are the tangible evidence of the fix.

---

## Lab 7 — Built-in Functions, Interpolation & Data Type Manipulation
**Maps to:** Built-in Functions and Interpolation; Data Types (Maps, Lists); Variable Manipulation (Length, Count, Join, Split, List/Map Conversion)
**Duration:** ~60 min

**What needs to be built:**
- A starter config with a list variable (e.g., a list of environment names: `["dev","staging","prod"]`).
- Tasks requiring `length()`, `join()`, `split()`, and list-to-map (or map-to-list) conversions to dynamically generate resource names and tags from that single list.

**Visible end result:** A **set of AWS resources whose names and tags were computed, not hardcoded** — participants see in the AWS Console that resource names/tags exactly match what their function logic produced from the source list, changing correctly if the list changes.

---

## Lab 8 — Loops, Backends & Scaling EC2 Configuration
**Maps to:** Creating Loops (via Count); Terraform Backends; Using Terraform to Configure EC2 Instances
**Duration:** ~75 min

**What needs to be built:**
- A `count`-based resource block to deploy N EC2 instances from one block.
- A migration task: move local state to a remote backend (S3 bucket + DynamoDB lock table).
- A second-session/second-machine check: another participant (or the same one, fresh terminal) runs `terraform plan` against the remote backend.

**Visible end result:** A **fleet of N EC2 instances** appears in the AWS Console from a single `count` block, and the `.tfstate` file is now **visible sitting in the S3 bucket** (not on their local disk) — confirmed by successfully running Terraform commands against that state from a different session, proving the backend migration worked.

---

## Lab 9 (Capstone) — Documentation Deep-Dive Challenge
**Maps to:** Terraform Documentation Deep-Dive; Mastery
**Duration:** ~60 min

**What needs to be built:**
- An open-ended challenge task: deploy a specific AWS resource type **not covered anywhere else in the course** (e.g., an S3 static website, or an Application Load Balancer), using only the Terraform Registry docs.
- No starter code provided — success depends on reading provider documentation independently.

**Visible end result:** A **working, previously-unseen resource type deployed entirely from scratch** — proof participants can now operate independently from documentation alone, not just from guided labs.

---

## Summary Table

| Lab | Topic Area | Core Deliverable Participant Walks Away With |
|---|---|---|
| 1. Environment Setup & First Project | Terraform Project basics | First real EC2 instance running |
| 2. Input Variables, Locals & Data Sources | Extending the project | Instance changes on re-apply via variables; local-exec proof file |
| 3. State Deep-Dive, Drift & Import | State & drift | Drift detected in `plan`; unmanaged resource successfully imported |
| 4. AWS Provider Deep-Dive Mini-App | AWS Provider | Live web page served from deployed infrastructure |
| 5. Templates, Modules & Workspaces | Reuse patterns | Two environments (dev/prod) from one reusable module |
| 6. Error Handling & Debugging | Errors & debugging | Broken apply fixed into a clean, successful apply |
| 7. Built-in Functions & Data Manipulation | Functions & data types | Resource names/tags computed dynamically from a list |
| 8. Loops, Backends & Scaling EC2 | Loops & backends | N EC2 instances via `count`; state migrated to S3 backend |
| 9. Documentation Deep-Dive Challenge (Capstone) | Mastery | New, unseen resource type deployed from docs alone |

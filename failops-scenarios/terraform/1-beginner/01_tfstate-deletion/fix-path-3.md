## 🧹 Fix Path 3: Recreate + Manually clean orphaned infra

This is the **last resort** recovery method — use it only when no other fix works.

Now you can simulate this using **Step 7 shown in README**:

[Re-Apply After State Loss](./README.md#-steps-to-break-it)

[Destroy or Halt VMs After Completion](../../README.md#-destroy-or-halt-vms-after-scenario-completion)

<br>

| When You’d Use This Option             | Why It Makes Sense                               |
| -------------------------------------- | ------------------------------------------------ |
| You lost `.tfstate`                    | No backup or remote backend                      |
| Resources are simple or easy to delete | You prefer starting clean than trying to recover |
| It’s a test/dev environment            | Not mission-critical, safe to destroy            |
| Cost control is more important         | Better to delete than risk orphaned infra        |

<br>

## ✅ Real-World AWS infra example:

Let's say your setup creates:

* An EC2 instance
* A security group
* A key pair

Here's your `main.tf`:

```hcl
provider "aws" {
  region = "us-east-1"
}

resource "aws_key_pair" "my_key" {
  key_name   = "prod-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow HTTP"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  ami                    = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.my_key.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]
}
```

<br>

### After `tfstate` file deletion

```bash
terraform plan
```

Terraform now says:

> "I don’t see anything in the state file. Let's create:
>
> * EC2 instance
> * Security group
> * Key pair"

But these already exist in AWS.

This causes **conflict**, like:

* ❌ Key pair name `prod-key` already exists
* ❌ Security group name `web-sg` already taken
* ❌ Creating duplicate EC2s = wasted cost

<br>

### 🧹 Manually Clean Up the Orphaned Infra in AWS Console

Open AWS Console:

* Navigate to **EC2 → Instances** → terminate the running instance
* Go to **EC2 → Security Groups** → delete `web-sg`
* Go to **EC2 → Key Pairs** → delete `prod-key`

🧠 This simulates cleaning up orphaned infra that Terraform no longer recognizes.

<br>

### 🔁 Re-run Terraform

```bash
terraform init
terraform apply
```

Now:

* Terraform sees a clean AWS environment
* It creates:

  * 🔄 New EC2 instance
  * 🔄 New security group
  * 🔄 New key pair
* And writes a **new `.tfstate`** tracking the new infra

<br>

## 📌 Why This Matters in Real Production

| Risk After `.tfstate` Loss | Without Cleanup          | With Manual Cleanup (Option 2) |
| -------------------------- | ------------------------ | ------------------------------ |
| EC2 not tracked            | Terraform re-creates it  | Cleanly recreated by you       |
| SG name conflict           | Plan fails or duplicated | Clean state, no conflict       |
| Billing cost               | 2 EC2s = 2x cost         | 1 EC2 after fresh apply        |
| Drift tracking             | Impossible               | Fixed after reapply            |

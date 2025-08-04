# 💥 FailOps Lab – Simulate & Learn from DevOps Failures

This is a hands-on lab where DevOps learners can **simulate real-world failures** — and learn how to fix them.

- 🧱 Terraform
- 🐳 Docker *(coming soon)*
- ⚙️ CI/CD pipelines *(coming soon)*

Each scenario lives in its own folder under `failops-scenarios/` and includes:
- 📄 What breaks
- 🛠 How to fix it
- ✅ How to verify it's resolved
- 📸 Screenshots + logs (where applicable)

<br>

> *⚠️ NOTE*: I’m a DevOps learner building this lab to simulate what can go wrong. 
> Everything you see here is the result of me breaking it, debugging it, and teaching myself — with help from logs, AI, docs, and real-world stories.
>
> 🧪 This project is actively being developed in public.
> New scenarios are added every week. [📜 See Changelog](./CHANGELOG.md) or follow on [@diksha_vig15](https://x.com/diksha_vig15)


<br>

## 👀 Just want to learn? 

Explore simulation folders under [`failops-scenarios/`](./failops-scenarios/)  
Each contains:

| File         | Purpose                      |
|--------------|------------------------------|
| `README.md`  | What breaks & how to simulate it |
| `fix.md`     | Step-by-step fix instructions |
| `verify.md`  | Checklist to confirm fix worked |

You can learn passively just by reading 📚  
OR try it hands-on with setup below 👇

<br>

## 🔧 How to Get Started

Each tool (Terraform, Docker, CI/CD) has its own setup guide.  
Start with Terraform:

📘 [Terraform Setup & Simulations →](./failops-scenarios/terraform/README.md)

<br>

## 🧱 Current Folder Structure
```bash
Dev-FailOps/
├── .env.example             # Example file for env secrets
├── .gitignore               # Ignore credentials etc.
├── README.md                # 👈 You're here!
│
├── failops-scenarios/       # 🔥 Simulation folders for each tool
│   ├── terraform/           # Real-world Terraform failures
│   ├── docker/              # (coming soon)
│   ├── cicd/                # (coming soon)
│
├── infra/                   # Supporting infrastructure (per tool)
│   ├── terraform/           # Terraform base config for scenarios
│   ├── minio-server-S3/     # S3 backend for tfstate storage
│   ├── provision/           # Shell provisioners (e.g., setup-minio.sh)
│   └── output/              # Vagrantfile rendered by Terraform
```
<br>

## 🧠 Why This Lab Exists

Failures are where real learning begins.

This project helps you:
- Simulate chaos 💥
- Fix it calmly 🧘‍♀️
- Document it 📘

<br>

## 👏 Contribute or Follow Along

You can:
- ⭐ Star or fork the repo on GitHub
- 🧪 Try a scenario and share your fix on X (Twitter)
- 🧩 Submit your own broken setup via PR!

<br>

## 🔐 .env.example
Use this as your base for secrets:

```bash
# MinIO credentials
export AWS_ACCESS_KEY_ID="your-minio-username"
export AWS_SECRET_ACCESS_KEY="your-minio-password"
```

```bash
# check that values are fetched before running `vagrant up` or `terraform init`
echo $AWS_SECRET_ACCESS_KEY 
```
> ⚠️ Be sure your real .env is listed in .gitignore to keep secrets safe!


# 💥 FailOps Lab – Simulate & Learn from DevOps Failures

This is a hands-on lab where DevOps learners can **simulate real-world failures** — and learn how to fix them.

- 🧱 Terraform
- 🐳 Docker *(coming soon)*
- ⚙️ CI/CD pipelines

Each scenario lives in its own folder under `failops-scenarios/` and includes:
- 📄 What breaks
- 🛠 How to fix it
- ✅ How to verify it's resolved
- 📸 Screenshots + logs (where applicable)

<br>

> *⚠️ NOTE*: I’m still learning DevOps. This lab is my way of understanding how things break.
> Everything you see here is the result of me breaking it, debugging it, and teaching myself — with help from logs, AI, docs, and real-world stories.

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
│   ├── cicd/                # Explanation of Pipeline flow (dev-staging/prod)
│   ├── minio-server-S3/     # S3 backend for tfstate storage
│   ├── provision/           # Shell provisioners (e.g., setup-nginx.sh)
│   └── output/              # Vagrantfile rendered by Terraform
```
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

<br>

## 🔨 Contributions? Forks?

This project is primarily a **self-learning lab** — everything here is tested, written, and maintained solo.

* You’re welcome to **fork**, try simulations, or adapt the format for your own labs
* If you see issues or ideas for failure cases, feel free to open a discussion!
* **Currently not accepting direct contributions** (still evolving too fast)

<br>

## 🧠 Why This Lab Exists

I realized I won’t really understand DevOps until I’ve **broken things intentionally** and fixed them.

This project helps me:

* Simulate failure 💥
* Stay calm 🧘‍♀️
* Fix it with clarity 🛠
* Grow by documenting it 📖

If it helps someone else too, that’s a bonus.

<br>

## 💬 Follow Progress

I share regular updates here:
* 💬 [@diksha_vig15](https://x.com/diksha_vig15)
* 📜 [Changelog](./CHANGELOG.md)

Thanks for visiting! 👋

# **What an `agent` is in Jenkins**

An **agent** is the **machine or node where your pipeline or stage will run**. Jenkins needs some compute resource to execute your steps like `sh`, `npm install`, `git checkout`, etc. The `agent` directive tells Jenkins **where to run the pipeline**.

<br>

## 1. `agent any` behavior

```groovy
pipeline {
    agent any
}
```

* `agent any` → Jenkins can run this pipeline on **any available agent**.
* If no additional agents are configured, Jenkins runs the pipeline on the **master/controller node** (the VM where Jenkins is installed).
* Every build runs on that VM unless you:

  * Connect extra agents (other VMs, Docker containers, cloud instances).
  * Use a stage-level agent with a specific label or Docker image.

<br>

## 2. Jenkins VM role

* The Jenkins server VM is the **controller** — orchestrates jobs, schedules builds, and manages plugins.
* It **can also act as an agent**, meaning it can execute builds itself.
* Jenkins **does not automatically install software**. Tools like Node.js, npm, zip, etc., must be installed manually or via scripts in your pipeline.

<br>

## 3. Stage-level agents

You can override the global agent per stage:

```groovy
pipeline {
    agent none
    stages {
        stage('Build') {
            agent { label 'linux' }
            steps { sh 'echo Build on Linux' }
        }
        stage('Test') {
            agent { label 'windows' }
            steps { bat 'echo Test on Windows' }
        }
    }
}
```

* Build runs on a Linux node, Test runs on Windows.
* Useful for pipelines needing multiple OS environments.

<br>

## 4. Docker agents

```groovy
pipeline {
    agent {
        docker { image 'node:18' }
    }
    stages {
        stage('Build') {
            steps {
                sh 'node -v'
            }
        }
    }
}
```

* Runs pipeline **inside a Docker container** with Node.js 18.
* Ensures consistent build environments regardless of host OS.

> Jenkins orchestrates the process but relies on **pre-installed tools and environment setup** on the agent.

<br>

## Key points

* `agent` = “where to run the pipeline or stage.”
* `any` = any available agent/node.
* Can be overridden per stage for flexibility.
* Useful for OS-specific builds, Docker isolation, or running multiple environments (staging/prod) in parallel.


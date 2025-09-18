# Build Stage

```groovy
pipeline {
    ....

    tools{
      nodejs 'NodeJS_18'
    }

    stages {
        ....

        stage('Install & Test') {
            parallel {
                stage('Frontend') {
                    steps {
                        dir('frontend') {
                            sh 'npm ci'
                            sh 'npm test' 
                        }
                    }
                }
                stage('Backend') {
                    steps {
                        dir('backend') {
                            sh 'npm ci'
                            sh 'npm test:unit'
                        }
                    }
                }
            }
        }

        stage('Build & Zip') {
            parallel {
                stage('Frontend Build') {
                    steps {
                        echo 'Building Frontend...'
                        dir('frontend') {
                            sh 'npm run build'
                            sh 'zip -r frontend.zip build'
                        }
                    }
                }

                stage('Backend Zip') {
                    steps {
                        echo 'Zip Backend...'
                        dir('backend') {
                            sh 'zip -r backend.zip . -x "node_modules/*"'
                        }
                    }
                }
            }
        }
    }
}
```

📸 [Build Output](https://www.youtube.com/watch?v=L9W_qiLrcYU) 

<br>

## Tools

```groovy
tools{
      nodejs 'NodeJS_18'
}
```

* Jenkins requires the pipeline to explicitly specify which tool version to load using the `tools {}` block.

<br>

## Testing

### Frontend: Install & Test

> [Frontend test file](https://github.com/dvig14/my-app-demo/blob/fd3c75e428cb06612606713a90d52f122a0cb270/frontend/src/App.test.js)

```groovy
stage('Install & Test') {
    parallel {
        stage('Frontend') {
            steps {
                dir('frontend') {
                    sh 'npm ci'
                    sh 'npm test' 
                }
            }
        }
    }
}
```
* **`dir('frontend') { ... }`** → tells Jenkins to run the commands inside the `frontend` folder of your repo.
* **`sh 'npm ci'`** → clean install all dependencies listed in `package-lock.json`.
* **`sh 'npm test'`** → executes unit tests, verifying component rendering, state, and small logic functions.

<br>

> ### 📦 `package.json`

* Your **project manifest**.
* Defines which libraries your project *depends on*.
* Example:

```json
{
  "dependencies": {
    "express": "^4.18.2"
  },
  "devDependencies": {
    "jest": "^29.5.0"
  }
}
```

This says: *“My project needs Express and Jest, but I don’t care which exact minor/patch versions, as long as they match the version ranges.”*

> ### 📦 `package-lock.json`

* Exact **snapshot** of all dependencies (including sub-dependencies).
* Locks down versions to make installs **reproducible**.
* Example (snippet):

```json
"express": {
  "version": "4.18.2",
  "resolved": "https://registry.npmjs.org/express/-/express-4.18.2.tgz",
  "integrity": "sha512-xyz..."
}
```

This guarantees that if two developers or CI pipelines run `npm ci`, they get **the same Express version, down to the checksum**.

> ### 📦 `node_modules/`

* The **actual installed code** of Express, Jest, Cypress, React, etc.
* Big folder, often not committed to Git.
* Node looks here when your code says `require('express')`.

| Command       | Behavior                                                                                                                                                                                   |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `npm install` | ✅ Creates/updates `node_modules`. <br> ✅ Uses `package.json` ranges. <br> ✅ Updates `package-lock.json` if versions drift. <br> ⚠️ Slower, can lead to slight differences across machines. |
| `npm ci`      | ✅ Deletes `node_modules` first. <br> ✅ Installs **exact versions** from `package-lock.json`. <br> ❌ Never updates lock file. <br> ⚡ Faster, deterministic, perfect for CI/CD.              |

📘 [Read about npm ci](https://stackoverflow.com/questions/52499617/what-is-the-difference-between-npm-install-and-npm-ci)

<br>

### Backend: Install & Test

> [Backend test file](https://github.com/dvig14/my-app-demo/blob/fd3c75e428cb06612606713a90d52f122a0cb270/backend/app.test.js)

```groovy
stage('Install & Test') {
    parallel {
        stage('Backend') {
            steps {
                dir('backend') {
                    sh 'npm ci'
                    sh 'npm test:unit'
                }
            }
        }
    }
}
```
* **`dir('backend') { ... }`** → run commands inside the `backend` folder.
* **`sh 'npm ci'`** → installs backend Node.js dependencies.
* **`sh 'npm test:unit'`** → runs unit tests on API endpoints, functions, and core business logic 

<br>

## **When to Run Tests / Quality Gates**

A **quality gate** is a checkpoint in the pipeline that blocks further execution unless certain criteria are met.
In this pipeline, the criteria are that all **frontend and backend unit tests pass**. If either fails, the pipeline stops immediately, preventing broken code from progressing to packaging or deployment.

<br>

| Stage                     | What Happens                                                                                                       |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| **CI (Build)**            | Run **unit tests** and optionally **integration tests** on the CI agent (before artifact storage).                 |
| **CD (Deploy + Staging)** | Deploy artifacts to the **staging environment**, then execute **automated end-to-end tests** (frontend + backend). |
| **Prod Deployment**       | Occurs **only if staging tests pass** (manual approval can be added as a gate).                                    |

**Key Points:**

1. **Unit tests before packaging** → catch code issues early and prevent storing broken artifacts.
   * CI → before packaging → artifact is only stored if tests pass.

2. **Automated tests after staging deploy** → validate deployment and environment configuration (ports, environment variables, API connectivity).
   * CD → after deploy → only then approve for production.


<br>

## Building

### Stage('Build')

```groovy
stage('Build') {
    parallel { ... }
}
```

* This is a **top-level stage** in Jenkins called `Build`.
* The `parallel {}` block tells Jenkins to run **multiple child stages at the same time** rather than one after the other.
* In our pipeline, it will run **Frontend Build** and **Backend Build** simultaneously.

<br>

### Frontend Build

```groovy
stage('Frontend Build') {
    steps {
        echo 'Building Frontend...'
        dir('frontend') {
            sh 'npm run build'
            sh 'zip -r frontend.zip build'
        }
    }
}
```

* **`echo 'Building Frontend...'`** → prints a message in Jenkins logs for clarity.
* **`dir('frontend') { ... }`** → tells Jenkins to run the commands inside the `frontend` folder of your repo.
* **`sh 'npm run build'`** → runs the build script, typically creates production-ready static files (in `/build` or `/dist`).
* **`sh 'zip -r frontend.zip build'`** → packages the build folder for versioned storage in MinIO

<br>

### Backend Build

```groovy
stage('Backend Build') {
    steps {
        echo 'Building Backend...'
        dir('backend') {
            sh 'zip -r backend.zip .'
        }
    }
}
```

* **`echo 'Building Backend...'`** → prints a message in logs.
* **`dir('backend') { ... }`** → run commands inside the `backend` folder.
* **`sh 'zip -r backend.zip . -x "node_modules/*"'`** → bundles all backend files into `backend.zip` for deployment, excluding `node_modules`.

<br>

### **Why Package as a Zip?**

* **Purpose:** To create a **deployable artifact**.
* Jenkins builds code on the CI server (or agent), but the **artifact must be transferred to the target server** (your Nginx VM).

**Benefits of packaging:**

1. **Consistency:** All code, configuration, and dependencies are bundled together.
2. **Versioning:** Can be stored in **MinIO (or S3)** as a specific build version.
3. **Reliable Deployment:** Ensures the same artifact tested in CI is deployed to staging/production.

<br>

> In real-world pipelines, backend artifacts may be zipped **or packaged as Docker images**, guaranteeing that **what was tested is exactly what gets deployed**.

<br>

*Without packaging, Jenkins would need to copy files manually each time, which is less robust and makes rollback harder.*
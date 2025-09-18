# Automated Tests (Staging) → Manual Approval → Deploy to production

```groovy
pipeline{
    ...
    stages {
        ...
        stage('Staging Tests') {
            when {
                branch 'develop'
            }
            environment {
               API_BASE_URL = "http://192.168.56.11:3001"   // Backend staging port
               FRONTEND_BASE_URL = "http://192.168.56.11:81"   // Frontend staging URL
            }
            parallel {
                stage('Frontend E2E Test') {
                    steps {
                        dir('tests/frontend') {
                            sh """
                                npm ci
                                npx cypress run
                            """   
                        }
                    }
                }
                stage('Backend API Test') {
                    steps {
                        dir('backend') {
                            sh """
                                export API_BASE_URL=$API_BASE_URL
                                npm ci
                                npm run test:staging
                            """
                        }
                    }
                }
            }
        }

        stage('Manual Approval for Production') {
            when { branch 'master' }
            steps {
                input "Approve Deployment to Production?"
            }
        }

        stage('Deploy to Production') {
            when {
                branch 'master'
            }
            steps {
                script {
                    deployApp('master', 'prod', '/var/www/my-app-prod', '/opt/my-app-backend-prod', 'my-app-backend-prod')
                }
            }
        }

        stage('Halt App VM') {
            agent { label 'windows' }
            steps {
                unstash 'output'
                dir('failops/infra/terraform/vagrant') {
                    bat """
                      terraform apply -var="vm_state=halt" -auto-approve=true
                    """
                }
            }
        }
    }
}
```

- 📸 [Deploy Staging Pipeline Overview](./assets/pipeline_succ.png)
- 📸 [App VM Website](./assets/app-vm.png)

<br>

## Install Cyress Dependencies For Setup 1

> This is needed for setup 1 only 

```bash
sudo apt-get install -y xvfb libgtk2.0-0 libgtk-3-0 \
    libgbm-dev libnotify-dev libnss3 libxss1 \
    libasound2 libx11-xcb1
```

* Cypress is **not just a test runner** it actually launches a real browser (Chrome etc).
* Jenkins VM is **headless** (no monitor, no GUI desktop).
* When Cypress tries to open Chrome, it says:

  > ❌ "I need a display but I can't find one."

That's why it asks for **Xvfb** → X virtual framebuffer.

* Xvfb simulates a display (a fake screen) so GUI apps can run headlessly.
* Without Xvfb, Chrome can’t start inside the VM.

<br>

### Why the extra libraries (`libgtk`, `libnss3`, etc.)

Those are the **native OS libraries** browsers need to render UI, handle graphics, sound, notifications, etc.
Even though Cypress doesn’t show you the GUI, Chrome still links against these libraries. If they’re missing → the browser crashes → Cypress can’t run.

* `libgtk*` → GUI toolkit libraries (window rendering).
* `libnss3` → network security support.
* `libxss1` → X11 screen saver extension.
* `libasound2` → sound driver library (needed even if no sound).

<br>

## Staging Tests Stage

```groovy
stage('Staging Tests') {
    when {
        branch 'develop'
    }
}
```

* `stage('Staging Tests')`: Defines a stage in the pipeline called 'Staging Tests'.
* `when { branch 'develop' }`: Only execute this stage if the current branch is `develop`. This prevents staging tests from running on production branches.

<br>

## **Environment Variables for Staging**

```groovy
environment {
   API_BASE_URL = "http://192.168.56.11:3001"   // Backend staging port
   FRONTEND_BASE_URL = "http://192.168.56.11:81"   // Frontend staging URL
}
```

* Sets environment variables **only for this stage**.
* `API_BASE_URL` points to your staging backend.
* `FRONTEND_BASE_URL` points to your staging frontend (Nginx serving on port 81).

> * For **Setup 1**, use the **57** subnet (http://192.168.57.11) instead of **56**.
> * 📘 [Network Concept](./network-concepts.md)

<br>

## Frontend End-to-End Tests

**Setup 1**
```groovy
stage('Frontend E2E Test') {
    steps {
        dir('tests/frontend') {
            sh """
              npm ci
              xvfb-run --auto-servernum -- npx cypress run 
            """
        }
    }
}
```

* `dir('tests/frontend') {}`: Switches to the `tests/frontend` folder (where Cypress tests are located).
* Shell commands executed here:

  1. `npm ci` → installs all Cypress and frontend test dependencies.
  2. `xvfb-run` → helper command that launches programs inside a fake X display (Xvfb).
  3. `--` → separates xvfb-run options from the actual command you want to run.
  4. `npx cypress run` → runs Cypress tests using the staging frontend URL inside the fake display.

**Setup 2**

```groovy
stage('Frontend E2E Test') {
    steps {
        dir('tests/frontend') {
            sh """
                npm ci
                npx cypress run
            """   
        }
    }
}
```

<br>

## Backend API Test

```groovy
stage('Backend API Test') {
    steps {
        dir('backend') {
            sh """
              export API_BASE_URL=$API_BASE_URL
              npm ci
              npm run test:staging
            """
        }
    }
}
```

* `dir('backend') {}` → Switches to the backend folder where your API tests live.
* `export API_BASE_URL=$API_BASE_URL` → sets backend staging URL for API tests.
* `npm ci` → installs backend dependencies (Jest, Supertest, etc.).
* `npm run test:staging` → runs your backend API tests against the staging server.

<br>

## **Manual Approval for Production**

```groovy
stage('Manual Approval for Production') {
    when { branch 'master' }
    steps {
        input "Approve Deployment to Production?"
    }
}
```

* Only executes on `master` branch.
* `input "Approve Deployment to Production?"` → pauses the pipeline and waits for a human to approve deployment. This prevents accidental auto-deploys to production.

<br>

## Production Deployment

```groovy
steps {
    script {
        deployApp('master', 'prod', '/var/www/my-app-prod', '/opt/my-app-backend-prod', 'my-app-backend-prod')
    }
}
```

* `script {}` allows you to run **Groovy script code** inside a declarative pipeline.
* `deployApp(...)` calls your **custom deployment function** (defined outside pipeline) that handles:
  
  1. Uploading frontend and backend artifacts.
  2. Installing dependencies.
  3. Restarting backend services via systemd.
  4. Deploying to the specified production paths.

**Parameters explained:**

  1. `'master'` → branch name
  2. `'prod'` → environment
  3. `'/var/www/my-app-prod'` → frontend folder on server
  4. `'/opt/my-app-backend-prod'` → backend folder on server
  5. `'my-app-backend-prod'` → systemd service name for backend

<br>

## **Branch-Based Pipeline Flow**

* **Develop Branch**:

  * Runs build → staging deployment → automated frontend + backend tests.
  * QA or automation validates the code on staging.

* **Main/Master Branch**:

  * Triggered by merging `develop` → `main/master`.
  * Runs build → full test suite → manual approval → production deployment.

<br>

| Branch      | Staging Deployment         | Production Deployment | Tests             | Approval      |
| ----------- | -------------------------- | --------------------- | ----------------- | ------------- |
| develop     | ✅ Automatic                | ❌ None                | ✅ Staging tests   | ❌ None        |
| main/master | ❌ Skip (already validated) | ✅ After approval      | ✅ Full test suite | ✅ Manual gate |

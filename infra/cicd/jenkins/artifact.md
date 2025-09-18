# **Artifact Storage**

```bash
wget https://dl.min.io/client/mc/release/linux-amd64/mc -O mc
chmod +x mc
sudo mv mc /usr/local/bin/

sudo su - jenkins
mc alias set minio-server http://192.168.56.22:9000 "<MINIO_USER>" "<MINIO_PASS>"
mc mb minio-server/my-app 
mc version enable minio-server/my-app
```

This installs the **MinIO client** on your Jenkins VM and creates a bucket named `my-app` on the MinIO server for storing artifacts. **Versioning** is enabled to maintain historical builds.

<br>

### Where the alias config lives
* `mc alias set ...` writes into `~/.mc/config.json` of the user who ran the command.
* That means:
  * If you ran it as `vagrant`, it lives in `/home/vagrant/.mc/config.json`
  * If you ran it as `root`, it lives in `/root/.mc/config.json`.
  * Jenkins jobs run as `jenkins`, so they look inside `/var/lib/jenkins/.mc/config.json`.

* Check:

```bash
cat ~/.mc/config.json
```

📸 [Bucket created](./assets/artifact-bucket.png)

<br>

```groovy
pipeline {
    ...
    environment {
        MINIO_ALIAS = "minio-server"
        MINIO_BUCKET = "my-app"
        BRANCH_NAME = "${env.BRANCH_NAME}"
        BUILD_ID_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
    }

    stages {
        ...
        stage('Upload Artifacts to MinIO') {
            steps {
                sh """
                mc cp frontend/frontend.zip $MINIO_ALIAS/$MINIO_BUCKET/frontend/$BRANCH_NAME/$BUILD_ID_TAG/
                mc cp backend/backend.zip  $MINIO_ALIAS/$MINIO_BUCKET/backend/$BRANCH_NAME/$BUILD_ID_TAG/
                """
            }
        }
    }
}
```

<br>

## **Why use the `environment {}` block instead of inline variables?**

* **Centralization:** Defines variables once instead of repeating values like `my-app` or `minio-server` multiple times.
* **Ease of maintenance:** Changing a bucket name or alias requires updating a single location.
* **Cleaner code:** Subsequent commands can reference `$MINIO_BUCKET` instead of long hard-coded strings.
* **Consistency:** Jenkins loads these variables before any stages run, ensuring uniform behavior.

<br>

## **Explanation of each variable**

```groovy
    MINIO_ALIAS = "minio-server"
    MINIO_BUCKET = "my-app"
    BRANCH_NAME = "${env.BRANCH_NAME}"
```

* **`MINIO_ALIAS`** → The name you gave your MinIO server when you ran
* **`MINIO_BUCKET`** → The S3/MinIO bucket used for storing build artifacts.
* **`BRANCH_NAME`** → The current Git branch name (`develop` or `master`).

<br>

```groovy
    BUILD_ID_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
```

* **`BUILD_ID_TAG`** → Combines:
  
  * `env.BUILD_NUMBER` → Jenkins build number (auto-incremented)
  * `env.GIT_COMMIT.take(7)` → First 7 characters of the commit hash

*Example:*

```
  42-a1b2c3d
```
This ensures **unique and human-readable versioning** for each build artifact.

<br>

## **Why use `BUILD_ID_TAG` even with versioning enabled?**

### MinIO/S3 Versioning

* When **versioning is enabled** on a bucket, every object (like `frontend.zip`) keeps **historical versions automatically**.
* Example:

  ```
  frontend.zip → v1 (older)
  frontend.zip → v2 (newer)
  ```
* ✅ You can roll back to a previous object version.
* ✅ You don’t have to manually create separate folders for each build.

📸 [Versioned bucket](./assets/my-app-versions.png)

<br>

### **Purpose of `BUILD_ID_TAG`**

* This is **pipeline-driven versioning**:

```
  frontend/<branch_name>/<build-number>-<git-hash>/frontend.zip
  backend/<branch_name>/<build-number>-<git-hash>/backend.zip
```

*Benefits over relying solely on MinIO versioning:*

1. **Traceability:** Quickly identify which Jenkins build and Git commit produced an artifact.
2. **Per-build isolation:** Test multiple builds side by side (e.g., staging vs rollback).
3. **Explicit automation reference:** Pipelines can reference specific folders rather than S3 version IDs.
4. **Independent of versioning:** Works even if MinIO versioning is disabled.

📸 [Build Id Tag](./assets/build-tag.png)


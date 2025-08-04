terraform {

  # === S3 Backend (MinIO) — No Locking ===

  backend "s3" {
    bucket                      = "terra-state"
    key                         = "demo.tfstate"
    region                      = "us-east-1"
    endpoints                   = {
      s3 = "http://192.168.56.22:9000"
    } 
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style              = true
  }

  # === Consul Backend (With Locking) ===
  # Comment out the above S3 block and uncomment the below block when testing lock conflict

  # backend "consul" {
  #  address = "127.0.0.1:8500"
  #  path    = "terraform/state/app"
  # }

}

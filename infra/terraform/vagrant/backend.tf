terraform {
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
}

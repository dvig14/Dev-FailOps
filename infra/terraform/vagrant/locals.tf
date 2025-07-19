locals {
  vms = [
    {
      name    = "sandbox"
      ip      = "192.168.56.12"
      memory  = 512
      path    = "${path.module}/../provision/sandbox.sh"
      enabled = var.sandbox_enable
    },
    {
      name    = "app"
      ip      = "192.168.56.11"
      memory  = 1024
      path    = "${path.module}/../provision/setup-nginx.sh"
      enabled = var.app_enable
    },
    {
      name    = "jenkins"
      ip      = "192.168.56.13"
      memory  = 2048
      path    = "${path.module}/../provision/install-jenkins.sh"
      enabled = var.jenkins_enable
    }
  ]

  vms_filtered = [
    for vm in local.vms : vm if vm.enabled
  ]

}


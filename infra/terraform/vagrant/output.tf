output "app_server_ip"{
   value = [for vm in local.vms : vm.ip if vm.name == "app"]
}

output "jenkins_server_ip"{
   value = [for vm in local.vms : vm.ip if vm.name == "jenkins"]
}

output "sandbox_server_ip"{
   value = [for vm in local.vms : vm.ip if vm.name == "sandbox"]
}
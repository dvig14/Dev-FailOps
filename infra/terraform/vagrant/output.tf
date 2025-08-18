output "app_server_ip"{
   value = [for vm in local.vms : vm.ip if vm.name == "app"]
}

output "sandbox_server_ip"{
   value = [for vm in local.vms : vm.ip if vm.name == "sandbox"]
}
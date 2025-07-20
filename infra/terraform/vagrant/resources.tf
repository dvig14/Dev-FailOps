data "template_file" "vagrantfile" {
  template = file("${path.module}/vagrantfile.tpl")

  vars = {
    vms_json = jsonencode(local.vms_filtered)
  }
}

resource "null_resource" "vagrantfile" {
  count = var.sandbox_enable || var.app_enable || var.jenkins_enable ? 1 : 0
  
  provisioner "local-exec" {
    command = <<EOT
    echo '${replace(data.template_file.vagrantfile.rendered, "'", "'\\''")}' | ./vagrantfile-gen.sh '${path.module}/../output/Vagrantfile'
    EOT
    working_dir = "${path.module}/../../provision"
    interpreter = ["bash", "-c"]
  }

}


resource "null_resource" "vagrant_op" {
  # First ensure vagrantfile is created as resources not linked 
  depends_on = [null_resource.vagrantfile]

  provisioner "local-exec" {
    command = "vagrant ${var.vm_state} ${var.vm_name != "" ? var.vm_name : ""}"
    working_dir = "${path.module}/../../output"
  }

  triggers = {
    vm_state = var.vm_state
    vm_name  = var.vm_name
  }
} 


resource "null_resource" "vagrant_destroy" {
  depends_on = [null_resource.vagrant_op]

  provisioner "local-exec" {
    when = destroy 
    command = "vagrant destroy -f"
    working_dir = "${path.module}/../../output" 
  }
}

resource "random_id" "demo_for_import_fix" {
  byte_length = 4
}
variable "sandbox_enable" {
  type = bool
  default = false
}

variable "app_enable" {
  type = bool
  default = false
}

variable "vm_state" {
  type = string
  default = "up" # or "halt"
}

variable "vm_name" {
  type = string
  default = "" 
}
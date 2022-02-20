### network
variable "subnets" {
  description = "The list of subnet IDs to deploy your EKS cluster"
  type        = list(string)
  default     = null
}

### kubernetes cluster
variable "kubernetes_version" {
  description = "The target version of kubernetes"
  type        = string
  default     = "1.20"
}

variable "managed_node_group" {
  description = "Amazon managed node group definition"
  type = object({
      name          = string
      min_size      = number
      max_size      = number
      desired_size  = number
      instance_type = string
  })
  default     =     {
      name          = "default"
      min_size      = 1
      max_size      = 3
      desired_size  = 1
      instance_type = "t2.micro"
    }
}

### feature
variable "enabled_cluster_log_types" {
  description = "A list of the desired control plane logging to enable"
  type        = list(string)
  default     = []
}

variable "enable_ssm" {
  description = "Allow ssh access using session manager"
  type        = bool
  default     = false
}

### security
variable "policy_arns" {
  description = "A list of policy ARNs to attach the node groups role"
  type        = list(string)
  default     = []
}

### description
variable "name" {
  description = "The logical name of the module instance"
  type        = string
  default     = null
}

### tags
variable "tags" {
  description = "The key-value maps for tagging"
  type        = map(string)
  default     = {}
}

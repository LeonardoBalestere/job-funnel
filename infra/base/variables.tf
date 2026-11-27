variable "name" {
  description = "Prefix for every resource name, and the name the k3s node registers under."
  type        = string
  default     = "job-funnel"
}

variable "region" {
  description = "AWS region of the permanent environment."
  type        = string
}

variable "availability_zone" {
  description = "The one availability zone the subnet, the instance and the data volume live in. The volume can only attach to instances in its own zone."
  type        = string
}

variable "vpc_cidr" {
  description = "Address range of the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "instance_types" {
  description = "Spot instance types the node may run on, in no particular order. All x86, because SQL Server does not run on ARM, and 8 GB, the budget validated in phase 0."
  type        = list(string)
  default     = ["m5.large", "m5a.large", "m6i.large", "m6a.large", "m7i.large", "m7a.large"]

  validation {
    condition     = length(var.instance_types) > 0
    error_message = "At least one instance type is required."
  }
}

variable "root_volume_size_gb" {
  description = "Size of the instance's root volume. It holds only the operating system; everything that must survive an interruption is on the data volume."
  type        = number
  default     = 20
}

variable "data_volume_size_gb" {
  description = "Size of the persistent data volume that holds k3s and every data store."
  type        = number
  default     = 40
}

variable "k3s_channel" {
  description = "k3s release channel installed when an instance starts, such as stable or v1.34. A minor channel keeps a replacement instance from jumping minor versions over the existing data."
  type        = string
  default     = "stable"
}

variable "hosted_zone_name" {
  description = "Name of the existing Route 53 public hosted zone of the owner's domain, such as example.com."
  type        = string
}

variable "api_hostname" {
  description = "Fully qualified host name of the API, inside the hosted zone, such as api.example.com."
  type        = string

  validation {
    condition     = endswith(var.api_hostname, ".${var.hosted_zone_name}")
    error_message = "The API host name must be inside the hosted zone."
  }
}

variable "service_images" {
  description = "One container image, and so one ECR repository, per process."
  type        = set(string)
  default     = ["catalog-api", "catalog-worker", "funnel-api", "dashboard-api"]
}

variable "image_retention_count" {
  description = "How many tagged images each repository keeps; older ones are expired."
  type        = number
  default     = 20
}

variable "github_repository" {
  description = "The GitHub repository, as owner/name, whose main branch may assume the deploy role. Case-sensitive, as GitHub writes it in the token."
  type        = string
  default     = "LeonardoBalestere/job-funnel"
}

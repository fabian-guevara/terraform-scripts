terraform {
  required_version = ">= 1.5.0"

  required_providers {
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = ">= 1.36.0"
    }
  }
}

provider "mongodbatlas" {}

variable "project_id" {
  type        = string
  description = "Atlas Project ID where the cluster will be created or managed."
}

variable "cluster_name" {
  type        = string
  description = "Atlas cluster name."
}

variable "provider_name" {
  type        = string
  description = "Cloud provider name."
  default     = "AWS"
}

variable "region_name" {
  type        = string
  description = "Cloud provider region name."
  default     = "US_EAST_1"
}

variable "baseline_instance_size" {
  type        = string
  description = "Baseline Atlas cluster tier."
  default     = "M80"
}

variable "scaled_instance_size" {
  type        = string
  description = "Scaled Atlas cluster tier."
  default     = "M140"
}

variable "scaled_disk_iops" {
  type        = number
  description = "Provisioned IOPS value for the scaled state."
  default     = 32000
}

variable "target_state" {
  type        = string
  description = "baseline = standard/default IOPS, scaled = provisioned IOPS"
  default     = "baseline"

  validation {
    condition     = contains(["baseline", "scaled"], var.target_state)
    error_message = "target_state must be baseline or scaled."
  }
}

locals {
  cluster_config = {
    baseline = {
      instance_size   = var.baseline_instance_size
      ebs_volume_type = "STANDARD"
      disk_iops       = null
    }

    scaled = {
      instance_size   = var.scaled_instance_size
      ebs_volume_type = "PROVISIONED"
      disk_iops       = var.scaled_disk_iops
    }
  }

  selected = local.cluster_config[var.target_state]

  electable_specs = merge(
    {
      instance_size   = local.selected.instance_size
      node_count      = 3
      ebs_volume_type = local.selected.ebs_volume_type
    },
    local.selected.disk_iops == null ? {} : {
      disk_iops = local.selected.disk_iops
    }
  )
}

resource "mongodbatlas_advanced_cluster" "cluster" {
  project_id             = var.project_id
  name                   = var.cluster_name
  cluster_type           = "REPLICASET"
  mongo_db_major_version = "8.0"

  replication_specs = [
    {
      num_shards = 1
      zone_name  = "Zone 1"

      region_configs = [
        {
          provider_name = var.provider_name
          region_name   = var.region_name
          priority      = 7

          electable_specs = local.electable_specs
        }
      ]
    }
  ]
}
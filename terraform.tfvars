rancher_env = {
  cloud_credential    = "esx1-vsphere"
  cluster_annotations = { "foo" = "bar" }
  cluster_labels      = { "something" = "amazing" }
  rke2_version        = "v1.27.10+rke2r1"
}

kubevip = {
  load_balancer_ip = "172.16.71.254"
}

# These are machine specs for nodes.  Be mindful of System Requirements!
node = {
  ctl_plane = { hdd_capacity = 40960, name = "ctl-plane", quantity = 3, vcpu = 4, vram = 4096 }
  worker    = { hdd_capacity = 81920, name = "worker", quantity = 4, vcpu = 4, vram = 8192 }
}

vsphere_env = {
  cloud_image_name = "sles15sp5-kiwi-template-v0.2"
  compute_node     = "any"
  datacenter       = "Datacenter1"
  datastore        = "datastore1"
  ds_url           = "ds:///vmfs/volumes/.../"
  library_name     = "templates"
  server           = "esx1-vsphere.weiss.ddnss.de"
  user             = "administrator@vsphere.local"
  vm_network       = ["192-168-0"]
}

clustername      = "rke2-vsphere"
stage            = "rke-prod"
registry01       = "registry01.suse"
registry02       = "registry02.suse:5000"
registryusername = "robot-rke2-vsphere"
registrypassword = "4tCFcThhx6q3iLxgFYIfENVd5UtI3kKm"
ntpservers       = ["192.168.0.31", "weiss-2.weiss.ddnss.de"]

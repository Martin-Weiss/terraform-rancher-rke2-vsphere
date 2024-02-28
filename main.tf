# create registry auth secret
resource "rancher2_secret_v2" "registryconfig-auth-registry01" {
  cluster_id = "local"
  name       = "registryconfig-auth-registry01-${var.clustername}"
  namespace  = "fleet-default"
  type       = "kubernetes.io/basic-auth"
  data = {
    username = var.registryusername
    password = var.registrypassword
  }
}

resource "rancher2_secret_v2" "registryconfig-auth-registry02" {
  cluster_id = "local"
  name       = "registryconfig-auth-registry02-${var.clustername}"
  namespace  = "fleet-default"
  type       = "kubernetes.io/basic-auth"
  data = {
    username = var.registryusername
    password = var.registrypassword
  }
}

resource "rancher2_machine_config_v2" "nodes" {
  for_each      = var.node
  generate_name = replace(each.value.name, "_", "-")

  vsphere_config {
    cfgparam   = ["disk.enableUUID=TRUE"] # Disk UUID is Required for vSphere Storage Provider
    clone_from = var.vsphere_env.cloud_image_name
    cloud_config = templatefile("${path.cwd}/files/user_data_${each.key}.tftmpl",
      {
        ssh_user       = "rancher",
        ssh_public_key = file("${path.cwd}/files/.ssh-public-key", )
        ntpservers     = var.ntpservers
    }) # End of templatefile
    content_library           = var.vsphere_env.library_name
    cpu_count                 = each.value.vcpu
    creation_type             = "template"
    datacenter                = var.vsphere_env.datacenter
    datastore                 = var.vsphere_env.datastore
    disk_size                 = each.value.hdd_capacity
    memory_size               = each.value.vram
    network                   = var.vsphere_env.vm_network
    vcenter                   = var.vsphere_env.server
    graceful_shutdown_timeout = "0"
  }
} # End of rancher2_machine_config_v2

resource "rancher2_cluster_v2" "rke2" {
  annotations        = var.rancher_env.cluster_annotations
  kubernetes_version = var.rancher_env.rke2_version
  labels             = var.rancher_env.cluster_labels
  name               = var.clustername

  rke_config {
    #    additional_manifest = templatefile("${path.cwd}/files/additional_manifests.tftmpl", {
    #      kube_vip_rbac    = data.http.kube_vip_rbac.response_body
    #      kube_vip_version = jsondecode(data.http.kube_vip_version.response_body)["tag_name"]
    #      load_balancer_ip = var.kubevip.load_balancer_ip
    #    })
    registries {
      configs {
        hostname                = var.registry01
        insecure                = false
        auth_config_secret_name = "registryconfig-auth-registry01-${var.clustername}"
      }
      configs {
        hostname                = var.registry02
        insecure                = false
        auth_config_secret_name = "registryconfig-auth-registry02-${var.clustername}"
      }
      mirrors {
        endpoints = ["https://${var.registry01}", "https://${var.registry02}"]
        hostname  = "docker.io"
        rewrites = {
          "^(?:library|)(.*)" = "${var.stage}/docker.io/$1"
        }
      }
      mirrors {
        endpoints = ["https://${var.registry01}", "https://${var.registry02}"]
        hostname  = "registry.suse.com"
        rewrites = {
          "(.*)" = "${var.stage}/registry.suse.com/$1"
        }
      }
      mirrors {
        endpoints = ["https://${var.registry01}", "https://${var.registry02}"]
        hostname  = "registry.rancher.com"
        rewrites = {
          "(.*)" = "${var.stage}/registry.rancher.com/$1"
        }
      }
    }
    chart_values = <<EOF
      rancher-vsphere-cpi:
        vCenter:
          host: ${var.vsphere_env.server}
          port: 443
          insecureFlag: true
          datacenters: ${var.vsphere_env.datacenter}
          username: ${var.vsphere_env.user}
          password: ${file("${path.cwd}/files/.vsphere-passwd")}
          credentialsSecret:
            name: "vsphere-cpi-creds"
            generate: true
        cloudControllerManager:
          nodeSelector:
            node-role.kubernetes.io/control-plane: 'true'

      rancher-vsphere-csi:
        vCenter:
          host: ${var.vsphere_env.server}
          port: 443
          insecureFlag: "1"
          datacenters: ${var.vsphere_env.datacenter}
          username: ${var.vsphere_env.user}
          password: ${file("${path.cwd}/files/.vsphere-passwd")}
          configSecret:
            name: "vsphere-config-secret"
            generate: true
        csiNode:
          nodeSelector: 
            node-role.kubernetes.io/worker: 'true'
        storageClass:
          allowVolumeExpansion: true
          #datastoreURL: ${var.vsphere_env.ds_url}

      #rke2-calico:
      #  felixConfiguration:
      #    wireguardEnabled: true
          
      #rke2-ingress-nginx:
      #  controller:
      #    config:
      #      ssl-protocols: "TLSv1.2 TLSv1.3"
      #    extraEnvs:
      #      - name: OPENSSL_FIPS
      #        value: "1"  
      #    publishService:
      #      enabled: true
      #    service:
      #      enabled: true
    EOF

    machine_global_config = <<EOF
      cni: calico
      kube-apiserver-arg: [ "admission-control-config-file=/etc/rancher/rke2/custom-rke2-pss.yaml" ]
    EOF

    dynamic "machine_pools" {
      for_each = var.node
      content {
        cloud_credential_secret_name = data.rancher2_cloud_credential.auth.id
        control_plane_role           = machine_pools.key == "ctl_plane" ? true : false
        etcd_role                    = machine_pools.key == "ctl_plane" ? true : false
        name                         = machine_pools.value.name
        quantity                     = machine_pools.value.quantity
        worker_role                  = machine_pools.key != "ctl_plane" ? true : false

        machine_config {
          kind = rancher2_machine_config_v2.nodes[machine_pools.key].kind
          name = replace(rancher2_machine_config_v2.nodes[machine_pools.key].name, "_", "-")
        }
      } # End of dynamic for_each content
    }   # End of machine_pools

    machine_selector_config {
      config = <<EOF
        cloud-provider-name: "rancher-vsphere"
        protect-kernel-defaults: true
        profile: "cis"
      EOF
      #config = {
      #  cloud-provider-name     = "rancher-vsphere"
      #  profile                 = "cis"
      #  protect-kernel-defaults = true # Required to install RKE2 with CIS Profile enabled
      #}
    } # End machine_selector_config
  }   # End of rke_config
}     # End of rancher2_cluster_v2

## Providers ##

terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token     = ""
  cloud_id  = ""
  folder_id = ""
  zone      = "ru-central1-b"
}

## MySQL Database ##

resource "yandex_mdb_mysql_cluster" "db_cluster" {
  name        = "cluster_dostavimvse"
  environment = "PRESTABLE"
  network_id  = yandex_vpc_network.network-1.id
  version     = "5.7"

  resources {
    resource_preset_id = "b1.micro"
    disk_type_id       = "network-ssd"
    disk_size          = 16
  }

  mysql_config = {
    sql_mode                      = "ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION"
    max_connections               = 100
    default_authentication_plugin = "MYSQL_NATIVE_PASSWORD"
    innodb_print_all_deadlocks    = true
  }

  host {
    zone      = "ru-central1-b"
    subnet_id = yandex_vpc_subnet.subnet-1.id
    assign_public_ip = false
    name    = "cluster_dostavimvse"
  }
}

resource "yandex_mdb_mysql_database" "database" {
  cluster_id = yandex_mdb_mysql_cluster.db_cluster.id
  name       = "dostavim"
}

resource "yandex_mdb_mysql_user" "john" {
  cluster_id = yandex_mdb_mysql_cluster.db_cluster.id
  name       = "john"
  password   = "fhdjenljf"

  permission {
    database_name = yandex_mdb_mysql_database.database.name
    roles         = ["ALL"]
  }

  connection_limits {
    max_questions_per_hour   = 1000
    max_updates_per_hour     = 200
    max_connections_per_hour = 300
    max_user_connections     = 40
  }
}

resource "yandex_mdb_mysql_user" "dostavimvse" {
    cluster_id = yandex_mdb_mysql_cluster.db_cluster.id
    name       = "dostavimvse"
    password   = "fhdjenljf"

    permission {
      database_name = yandex_mdb_mysql_database.database.name
      roles         = ["ALL"]
    }

    connection_limits {
      max_questions_per_hour   = 1000
      max_updates_per_hour     = 200
      max_connections_per_hour = 300
      max_user_connections     = 40
    }
}

## Servers ##

resource "yandex_compute_instance" "vm-1" {
  name = "terraform1"

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  scheduling_policy {
    preemptible = true
  }

  boot_disk {
    initialize_params {
      image_id = "fd8kb72eo1r5fs97a1ki"
      size     = 8
    }
  }

  connection {
    type        = "ssh"
    user        = var.yc_user
    private_key = file(var.ssh_key)
    host        = self.network_interface[0].nat_ip_address
  }

  provisioner "file" {
    source      = "./install-vm2.sh"
    destination = "/home/${var.yc_user}/install-vm2.sh"
  }

  provisioner "file" {
    source      = "./populate_db.sh"
    destination = "/home/${var.yc_user}/populate_db.sh"
  }

  provisioner "file" {
    source      = "./CREATE.sql"
    destination = "/home/${var.yc_user}/CREATE.sql"
  }

  provisioner "file" {
    source      = "./connect_db.sh"
    destination = "/home/${var.yc_user}/connect_db.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo bash /home/${var.yc_user}/populate_db.sh ${yandex_mdb_mysql_cluster.db_cluster.host.0.fqdn}"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "sudo bash /home/${var.yc_user}/install-vm2.sh"
    ]
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
    ssh-keys = "${var.yc_user}:${file("${var.ssh_key}.pub")}"
  }
}

resource "yandex_compute_instance" "vm-2" {
  name = "terraform2"

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  scheduling_policy {
    preemptible = true
  }

  boot_disk {
    initialize_params {
      image_id = "fd8kb72eo1r5fs97a1ki"
      size     = 8
    }
  }

  connection {
    type        = "ssh"
    user        = var.yc_user
    private_key = file(var.ssh_key)
    host        = self.network_interface[0].nat_ip_address
  }

  provisioner "file" {
    source      = "./connect_db.sh"
    destination = "/home/${var.yc_user}/connect_db.sh"
  }

  provisioner "file" {
    source      = "./populate_db.sh"
    destination = "/home/${var.yc_user}/populate_db.sh"
  }

  provisioner "file" {
    source      = "./CREATE.sql"
    destination = "/home/${var.yc_user}/CREATE.sql"
  }

  provisioner "file" {
    source      = "./install-vm2.sh"
    destination = "/home/${var.yc_user}/install-vm2.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo bash /home/${var.yc_user}/install-vm2.sh"
    ]
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
    ssh-keys = "${var.yc_user}:${file("${var.ssh_key}.pub")}"
  }
}

## Load balancer ##

resource "yandex_alb_target_group" "foo" {
  name = "my-target-group"

  target {
    subnet_id  = yandex_vpc_subnet.subnet-1.id
    ip_address = yandex_compute_instance.vm-1.network_interface.0.ip_address
  }
  target {
    subnet_id  = yandex_vpc_subnet.subnet-1.id
    ip_address = yandex_compute_instance.vm-2.network_interface.0.ip_address
  }

}

resource "yandex_alb_backend_group" "test-backend-group" {
  name = "my-backend-group"

  http_backend {
    name             = "test-http-backend"
    weight           = 1
    port             = 80
    target_group_ids = ["${yandex_alb_target_group.foo.id}"]
    load_balancing_config {
      panic_threshold = 50
    }
    healthcheck {
      timeout          = "1s"
      interval         = "1s"
      healthcheck_port = 8080
      http_healthcheck {
        path = "/"
      }
    }
  }
}

resource "yandex_alb_virtual_host" "my-virtual-host" {
  name           = "my-virtual-host"
  http_router_id = yandex_alb_http_router.tf-router.id
  route {
    name = "my-route"
    http_route {
      http_match {
        http_method = []
        path {
          prefix = "/"
        }
      }
      http_route_action {
        backend_group_id = yandex_alb_backend_group.test-backend-group.id
        timeout          = "3s"
      }
    }
  }
}

resource "yandex_alb_http_router" "tf-router" {
  name = "my-http-router"
  labels = {
    tf-label    = "tf-label-value"
    empty-label = ""
  }
}

resource "yandex_alb_load_balancer" "test-balancer" {
  name = "my-load-balancer"

  network_id = yandex_vpc_network.network-1.id

  allocation_policy {
    location {
      zone_id   = "ru-central1-b"
      subnet_id = yandex_vpc_subnet.subnet-1.id
    }
  }

  listener {
    name = "my-listener"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [8080]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.tf-router.id
      }
    }
  }
}

## Network ##

resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

## DNS records ##

resource "yandex_dns_zone" "zone1" {
  name        = "my-private-zone"
  description = "redirect db to actual db addr"

  zone             = "app."
  public           = false
  private_networks = [yandex_vpc_network.network-1.id]
}

resource "yandex_dns_recordset" "rs1" {
  zone_id = yandex_dns_zone.zone1.id
  name    = "db.app."
  type    = "CNAME"
  ttl     = 200
  data    = ["c-${yandex_mdb_mysql_cluster.db_cluster.id}.rw.mdb.yandexcloud.net"]
}

## Outputs ##

output "database_fqdn" {
  value = yandex_mdb_mysql_cluster.db_cluster.host.0.fqdn
}

output "internal_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.ip_address
}

output "external_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.nat_ip_address
}

output "internal_ip_address_vm_2" {
  value = yandex_compute_instance.vm-2.network_interface.0.ip_address
}

output "external_ip_address_vm_2" {
  value = yandex_compute_instance.vm-2.network_interface.0.nat_ip_address
}

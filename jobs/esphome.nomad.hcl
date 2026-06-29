job "esphome" {
  datacenters = ["dc1"]
  type = "service"

  group "esphome" {
    count = 1

    network {
      mode = "host"
      port "http" {
        static = 6052
      }
    }

    service {
      name = "esphome"
      port = "http"
      tags = [
        "homeassistant",
        "global"
      ]
      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "esphome" {
      driver = "docker"

      config {
        image = "ghcr.io/esphome/esphome:latest"
        network_mode = "host"
        
        # Mount the CIFS share for the configuration files
        # Mount the local allocation directory for the heavy .esphome build cache
        volumes = [
          "/mnt/Public/config/ESPhome:/config",
          "local/build:/config/.esphome"
        ]
      }

      env {
        # Ensure it knows where to build
        ESPHOME_BUILD_PATH = "/config/.esphome"
      }

      resources {
        cpu    = 1000
        memory = 1024
      }
    }
  }
}

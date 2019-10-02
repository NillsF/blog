provider "kubernetes" {

}

resource "kubernetes_deployment" "example" {
  metadata {
    name = "private-api"
    labels = {
      app = "private-api"
    }
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "private-api"
      }
    }
    template {
      metadata {
        labels = {
          app = "private-api"
        }
      }
      spec {
        container {
          image = "nginx:1.7.8"
          name  = "private-api"

          resources {
            limits {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests {
              cpu    = "250m"
              memory = "50Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/nginx_status"
              port = 80

              http_header {
                name  = "X-Custom-Header"
                value = "Awesome"
              }
            }

            initial_delay_seconds = 3
            period_seconds        = 3
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "example" {
  metadata {
    name = "private-api"
    annotations = {
        "service.beta.kubernetes.io/azure-load-balancer-internal" = "true"
    }
  }
  spec {
    selector = {
      app = "private-api"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}
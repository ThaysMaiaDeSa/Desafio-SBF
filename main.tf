# Exemplo para Criacao de projeto Google
# Vou usar a regiao Carolina do Sul por ser uma das mais baratas, porem pode ser qualquer regiao indicada pela empresa
provider "google" {
 credentials = file("CREDENTIALS_FILE.json")
 project     = "nome-projeto"
 region      = "us-east1"
}

# Necessaria a configuracao do Cloud Identity a nivel da organizacao junto com Infraestrutura/Seguranca
# Necessaria a configuracao de VPC e Networking junto com Infraestrutura/Seguranca
# Necessaria a definicao do nivel de acesso de usuarios no IAM junto com Governanca. O ideal eh a definicao de grupos de acesso.


# Exemplo de criacao de buckets no Cloud Storage
# Necessario incluir o permissionamento definido por Governanca
resource "google_storage_bucket" "static-site" {
  name          = "image-store.com"
  location      = "us-east1-b"
  force_destroy = true

  uniform_bucket_level_access = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }
  cors {
    origin          = ["http://image-store.com"]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
}

# Foi mantido o padrao do lifecicle de 3 dias, porem isto precisa ser melhor definido de acordo com a solucao
# Foi incluido o tipo de storage como "STANDARD" porem isto pode ser alterado de acordo com a definicao da solucao e impacta diretamente no custo
resource "google_storage_bucket" "auto-expire" {
  name          = "auto-expiring-bucket"
  location      = "us-east1-b"
  force_destroy = true
  storage_class = "STANDARD"

  lifecycle_rule {
    condition {
      age = 3
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_storage_bucket_access_control" "public_rule" {
  bucket = google_storage_bucket.bucket.name
  role   = "READER"
  entity = "group-example@googlegroups.com"
}


# Exemplo de criacao de datasets no BigQuery
# Necessario incluir o permissionamento definido por Governanca
resource "google_bigquery_dataset" "dataset" {
  dataset_id                  = "example_dataset"
  friendly_name               = "test"
  description                 = "This is a test description"
  location                    = "us-east1-b"
  default_table_expiration_ms = 3600000

  default_encryption_configuration {
    kms_key_name = google_kms_crypto_key.crypto_key.id
  }
}

resource "google_kms_crypto_key" "crypto_key" {
  name     = "example-key"
  key_ring = google_kms_key_ring.key_ring.id
}

resource "google_kms_key_ring" "key_ring" {
  name     = "example-keyring"
  location = "us-east1-b"
}

resource "google_bigquery_dataset_access" "access" {
  dataset_id    = google_bigquery_dataset.private.dataset_id
  view {
    project_id = google_bigquery_table.public.project
    dataset_id = google_bigquery_dataset.public.dataset_id
    table_id   = google_bigquery_table.public.table_id
  }
}

resource "google_bigquery_dataset" "private" {
  dataset_id = "example_dataset"
}


# Exemplo de Cloud Composer
resource "google_composer_environment" "test" {
  name   = "mycomposer"
  region = "us-east1"
  config {
    node_count = 4

    node_config {
      zone         = "us-east1-b"
      machine_type = "e2-medium"

      network    = google_compute_network.test.id
      subnetwork = google_compute_subnetwork.test.id

      service_account = google_service_account.test.name
    }
  }

  config {
    software_config {
      airflow_config_overrides = {
        core-load_example = "True"
      }

      pypi_packages = {
        numpy = ""
        scipy = "==1.1.0"
      }

      env_variables = {
        FOO = "bar"
      }
    }
  }

  config {
    software_config {
      image_version = data.google_composer_image_versions.all.image_versions[0].image_version_id
    }
  }
}

resource "google_compute_network" "test" {
  name                    = "composer-test-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "test" {
  name          = "composer-test-subnetwork"
  ip_cidr_range = "10.2.0.0/16"
  region        = "us-east1"
  network       = google_compute_network.test.id
}

resource "google_service_account" "test" {
  account_id   = "composer-env-account"
  display_name = "Test Service Account for Composer Environment"
}

resource "google_project_iam_member" "composer-worker" {
  role   = "roles/composer.worker"
  member = "serviceAccount:${google_service_account.test.email}"
}

data "google_composer_environment" "composer_env" {
    name = google_composer_environment.test.name

    depends_on = [google_composer_environment.composer_env]
}

output "debug" {
    value = data.google_composer_environment.composer_env.config
}


# Exemplo de Pub/Sub
# Topico
data "google_iam_policy" "admin" {
  binding {
    role = "roles/viewer"
    members = [
      "user:jane@example.com",
    ]
  }
}

resource "google_pubsub_topic_iam_policy" "policy" {
  project = google_pubsub_topic.example.project
  topic = google_pubsub_topic.example.name
  policy_data = data.google_iam_policy.admin.policy_data
}


resource "google_pubsub_topic" "example" {
  name         = "example-topic"
  kms_key_name = google_kms_crypto_key.crypto_key.id
}

resource "google_kms_crypto_key" "crypto_key" {
  name     = "example-key"
  key_ring = google_kms_key_ring.key_ring.id
}

resource "google_kms_key_ring" "key_ring" {
  name     = "example-keyring"
  location = "global"
}

# Subscricao
data "google_iam_policy" "admin" {
  binding {
    role = "roles/editor"
    members = [
      "user:jane@example.com",
    ]
  }
}

resource "google_pubsub_subscription_iam_policy" "editor" {
  subscription = "your-subscription-name"
  policy_data  = data.google_iam_policy.admin.policy_data
}

resource "google_pubsub_subscription_iam_binding" "editor" {
  subscription = "your-subscription-name"
  role         = "roles/editor"
  members = [
    "user:jane@example.com",
  ]
}

resource "google_pubsub_subscription_iam_member" "editor" {
  subscription = "your-subscription-name"
  role         = "roles/editor"
  member       = "user:jane@example.com"
}

resource "google_pubsub_topic" "example" {
  name = "example-topic"

  labels = {
    foo = "bar"
  }
}


# Exemplo de Criacaoo de Compute Engine (Caso necessario para o pullying de APIs)
resource "google_service_account" "default" {
  account_id   = "service_account_id"
  display_name = "Service Account"
}

resource "google_compute_instance" "default" {
  name         = "pull-api-xxx"
  machine_type = "e2-medium"
  zone         = "us-east1"

  tags = ["xxx", "yyy"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  // Local SSD disk
  scratch_disk {
    interface = "SCSI"
  }

  network_interface {
    network = "default"

    access_config {
      // Incluir IP definido pela empresa
    }
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.default.email
    scopes = ["cloud-platform"]
  }
}
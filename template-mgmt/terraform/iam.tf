# ==========================================================
# 👥 IAM Governance (Project-Level Collaboration)
# ==========================================================

# Required GCP APIs for Management Plane
resource "google_project_service" "iam_apis" {
  for_each = toset([
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
  ])

  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

locals {
  # Ensure user: prefix for emails
  formatted_project_admins = [
    for member in var.project_admins :
    startswith(member, "user:") || startswith(member, "group:") || startswith(member, "serviceAccount:") ? member : "user:${member}"
  ]

  formatted_project_members = [
    for member in var.project_members :
    startswith(member, "user:") || startswith(member, "group:") || startswith(member, "serviceAccount:") ? member : "user:${member}"
  ]
}

# ------------------------------------------------------------------------------
# Project Admins: Editor access on the management project
# ------------------------------------------------------------------------------
resource "google_project_iam_member" "project_admins_editor" {
  for_each = toset(local.formatted_project_admins)

  project = var.project_id
  role    = "roles/editor"
  member  = each.value
}

# ------------------------------------------------------------------------------
# Project Members: Viewer access on the management project
# ------------------------------------------------------------------------------
resource "google_project_iam_member" "project_members_viewer" {
  for_each = toset(local.formatted_project_members)

  project = var.project_id
  role    = "roles/viewer"
  member  = each.value
}

output "whitelist_gcs_bucket_name" {
  description = "The name of the GCS bucket to store the script whitelists."
  value       = google_storage_bucket.main.name
}

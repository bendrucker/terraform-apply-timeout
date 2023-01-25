resource "null_resource" "this" {}

resource "time_sleep" "minute" {
  create_duration = "1m"
}

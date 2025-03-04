resource "aws_cloudwatch_log_group" "this" {
  name              = "gpt-api-kawagoe-log"
  retention_in_days = 180
  tags = {
    Name = "gpt-api-kawagoe-log"
  }
}
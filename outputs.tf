output "cur_bucket_name" {
  description = "S3 bucket for Cost and Usage Reports"
  value       = aws_s3_bucket.cur_bucket.bucket
}

output "cloudwatch_dashboard_url" {
  description = "URL to access the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.cost_dashboard.dashboard_name}"
}

output "sns_topic_arn" {
  description = "SNS Topic ARN for billing alerts"
  value       = aws_sns_topic.billing_alert.arn
}

output "lambda_function_name" {
  description = "Lambda function for resource scheduling"
  value       = aws_lambda_function.resource_scheduler.function_name
}

output "eventbridge_rule_name" {
  description = "EventBridge rule for scheduling"
  value       = aws_cloudwatch_event_rule.scheduler.name
}

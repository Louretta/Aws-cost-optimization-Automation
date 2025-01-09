

provider "aws" {
  region = var.aws_region
}


resource "aws_resourcegroups_group" "cost_monitoring" {
  name = "cost-monitoring-group"

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key = "Environment"
          Values = ["Production", "Development", "Staging"]
        },
        {
          Key = "CostCenter"
          Values = ["IT", "Operations", "Development"]
        }
      ]
    })
  }

  tags = {
    Project     = "Cost-Optimization"
    Environment = "Production"
    CostCenter  = "IT"
  }
}

resource "aws_budgets_budget" "monthly" {
  name              = "monthly-budget"
  budget_type       = "COST"
  limit_amount      = "1000"
  limit_unit        = "USD"
  time_period_start = "2024-01-01_00:00"
  time_unit         = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = ["eyinaejiro@gmail.com"]
  }
}

#create cost and usuage report 
resource "aws_cur_report_definition" "cost_report" {
  report_name                = "cost-usage-report"
  time_unit                  = "HOURLY"
  format                     = "textORcsv"
  compression                = "GZIP"
  additional_schema_elements = ["RESOURCES"]
  s3_bucket                  = "eloure-bucket-name"
  s3_region                  = "ca-central-1"
  additional_artifacts       = ["QUICKSIGHT"]

}

#create s3cbucket for cur 
resource "aws_s3_bucket" "cur_bucket" {
  bucket = "eloure-bucket-name"
}


resource "aws_s3_bucket_policy" "cur_bucket_policy" {
  bucket = aws_s3_bucket.cur_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CURBucketPolicy"
        Effect = "Allow"
        Principal = {
          Service = "billingreports.amazonaws.com"
        }
        Action = [
          "s3:GetBucketAcl",
          "s3:GetBucketPolicy",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.cur_bucket.arn,
          "${aws_s3_bucket.cur_bucket.arn}/*"
        ]
      }
    ]
  })
}

#create cloud watch dashboard 
resource "aws_cloudwatch_dashboard" "cost_dashboard" {
  dashboard_name = "cost-usage-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Billing", "EstimatedCharges", "Currency", "USD"]
          ]
          period = 86400
          stat   = "Maximum"
          region = "us-east-1"
          title  = "Estimated Monthly Charges"
        }
      }
    ]
  })
}

#create cloud watch alarms 
resource "aws_cloudwatch_metric_alarm" "billing_alarm" {
  alarm_name          = "billing-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period             = "21600" 
  statistic          = "Maximum"
  threshold          = "1000"
  alarm_description  = "Billing alarm when estimated charges exceed $1000"
  alarm_actions      = [aws_sns_topic.billing_alert.arn]

  dimensions = {
    Currency = "USD"
  }
}

#create sns topic 
resource "aws_sns_topic" "billing_alert" {
  name = "billing-alert-topic"
}

# Lambda Packaging with archive_file
data "archive_file" "lambda_package" {
  type        = "zip"
  source_dir  = "${path.module}/LAMBDA_DIR"
  output_path = "${path.module}/resource_scheduler.zip"
}

# Lambda Function for Resource Scheduling
resource "aws_lambda_function" "resource_scheduler" {
  filename      = data.archive_file.lambda_package.output_path
  function_name = "resource-scheduler"
  role          = aws_iam_role.lambda_role.arn
  handler       = "resource_scheduler.handler"
  runtime       = "python3.9"
  timeout       = 300

  environment {
    variables = {
      START_TIME = "0800"
      STOP_TIME  = "1800"
      TIMEZONE   = "EST"
    }
  }
}

# EventBridge Rule for Scheduling
resource "aws_cloudwatch_event_rule" "scheduler" {
  name                = "resource-scheduler"
  description         = "Schedule for starting and stopping resources"
  schedule_expression = "cron(0 8,18 ? * MON-FRI *)"
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.scheduler.name
  target_id = "ResourceScheduler"
  arn       = aws_lambda_function.resource_scheduler.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.resource_scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scheduler.arn
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "resource_scheduler_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda
resource "aws_iam_policy" "lambda_policy" {
  name = "resource_scheduler_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["ec2:DescribeInstances", "ec2:StartInstances", "ec2:StopInstances", "rds:DescribeDBInstances", "rds:StartDBInstance", "rds:StopDBInstance"]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}
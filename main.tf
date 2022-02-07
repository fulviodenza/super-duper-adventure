provider "aws" {
  region  = var.aws_region
}

variable "aws_region" {
  description = "AWS region for all resources."

  type    = string
  default = "eu-west-1"
}

variable "profile" {
  default = "dev-01"
}

variable "region" {
  default = "eu-west-1"
}

data "archive_file" "auth_file" {
  type = "zip"
  source_file = "${path.module}/target/auth"
  output_path = "${path.module}/target/auth.zip"
}

data "archive_file" "get_file" {
  type = "zip"
  source_file = "${path.module}/target/get"
  output_path = "${path.module}/target/get.zip"
}

data "archive_file" "post_file" {
  type = "zip"
  source_file = "${path.module}/target/post"
  output_path = "${path.module}/target/post.zip"
}

resource "random_pet" "lambda_bucket_name" {
  prefix = "rnd-bkt"
  length = 4
}

resource "aws_s3_bucket" "b" {
  bucket = random_pet.lambda_bucket_name.id

  acl           = "private"
  force_destroy = true
}

resource "aws_s3_bucket_object" "auth_object" {
  bucket = aws_s3_bucket.b.id
  key = "auth.zip"
  source = data.archive_file.auth_file.output_path
  etag = filemd5(data.archive_file.auth_file.output_path)
}

resource "aws_s3_bucket_object" "get_object" {
  bucket = aws_s3_bucket.b.id
  key = "get.zip"
  source = data.archive_file.get_file.output_path
  etag = filemd5(data.archive_file.get_file.output_path)
}

resource "aws_s3_bucket_object" "post_object" {
  bucket = aws_s3_bucket.b.id
  key = "post.zip"
  source = data.archive_file.post_file.output_path
  etag = filemd5(data.archive_file.post_file.output_path)
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# resource "aws_iam_policy" "policy" {
#   name        = "test-policy"
#   description = "A test policy"

#   policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Action": [
#         "ec2:Describe*"
#       ],
#       "Effect": "Allow",
#       "Resource": "*"
#     }
#   ]
# }
# EOF
# }

resource "aws_lambda_function" "auth" {
  function_name    = "auth"
  filename         = data.archive_file.auth_file.output_path
  handler          = "auth"
  source_code_hash = data.archive_file.auth_file.output_base64sha256
  role             = "${aws_iam_role.iam_for_lambda.arn}"
  runtime          = "go1.x"
  memory_size      = 128
  timeout          = 10
}

resource "aws_lambda_function" "tasks_function" {
  function_name    = "tasks"
  filename         = data.archive_file.get_file.output_path
  handler          = "tasks"
  source_code_hash = data.archive_file.get_file.output_base64sha256
  role             = "${aws_iam_role.iam_for_lambda.arn}"
  runtime          = "go1.x"
  memory_size      = 128
  timeout          = 10
}

resource "aws_lambda_function" "task_function" {
  function_name    = "task"
  filename         = data.archive_file.post_file.output_path
  handler          = "task"
  source_code_hash = data.archive_file.post_file.output_base64sha256
  role             = "${aws_iam_role.iam_for_lambda.arn}"
  runtime          = "go1.x"
  memory_size      = 128
  timeout          = 10
}

resource "aws_lambda_permission" "auth_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.api_gw.execution_arn}/*/*/*"
}

resource "aws_lambda_permission" "tasks_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tasks_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.api_gw.execution_arn}/*/*/*"
}

resource "aws_lambda_permission" "task_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.task_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.api_gw.execution_arn}/*/*/*"
}

resource "aws_api_gateway_rest_api" "api_gw" {
  name = "gateway"
}

# GET TASKS

resource "aws_api_gateway_resource" "tasks_resource" {
  path_part   = "tasks"
  parent_id   = "${aws_api_gateway_rest_api.api_gw.root_resource_id}"
  rest_api_id = "${aws_api_gateway_rest_api.api_gw.id}"
}

resource "aws_api_gateway_method" "get_tasks" {
  rest_api_id      = aws_api_gateway_rest_api.api_gw.id
  resource_id      = aws_api_gateway_resource.tasks_resource.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = false
}

resource "aws_api_gateway_integration" "get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gw.id
  resource_id             = aws_api_gateway_resource.tasks_resource.id
  http_method             = aws_api_gateway_method.get_tasks.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.tasks_function.invoke_arn
}

resource "aws_api_gateway_method_response" "tasks_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.tasks_resource.id
  http_method = aws_api_gateway_method.get_tasks.http_method
  status_code = "200"
}

# POST TASK

resource "aws_api_gateway_resource" "task_resource" {
  path_part   = "task"
  parent_id   = "${aws_api_gateway_rest_api.api_gw.root_resource_id}"
  rest_api_id = "${aws_api_gateway_rest_api.api_gw.id}"
}

resource "aws_api_gateway_authorizer" "task_authorizer" {
    name = "gateway-authorizer"
    rest_api_id = aws_api_gateway_rest_api.api_gw.id
    authorizer_uri = aws_lambda_function.auth.invoke_arn
    authorizer_credentials = aws_iam_role.iam_for_lambda.arn
}

resource "aws_api_gateway_method" "post_task" {
  rest_api_id      = aws_api_gateway_rest_api.api_gw.id
  resource_id      = aws_api_gateway_resource.task_resource.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = false
  authorizer_id = aws_api_gateway_authorizer.task_authorizer.id
}

resource "aws_api_gateway_integration" "post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gw.id
  resource_id             = aws_api_gateway_resource.task_resource.id
  http_method             = aws_api_gateway_method.post_task.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.task_function.invoke_arn
}

resource "aws_api_gateway_method_response" "task_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.task_resource.id
  http_method = aws_api_gateway_method.post_task.http_method
  status_code = "200"
}

# IAM

resource "aws_iam_policy" "policy" {
  name        = "test-policy01"
  description = "A test policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:Describe*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_iam_role_policy" "invocation_policy" {
  name = "default"
  role = aws_iam_role.iam_for_lambda.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "lambda:InvokeFunction",
        "execute-api:Invoke",
        "logs:PutLogEvents",
        "logs:PutLogEventsBatch",
        "logs:CreateLogStream"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_lambda_function.tasks_function.arn}"
      ]
    },
    {
      "Action": [
        "lambda:InvokeFunction",
        "execute-api:Invoke",
        "logs:PutLogEvents",
        "logs:PutLogEventsBatch",
        "logs:CreateLogStream"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_lambda_function.task_function.arn}"
      ]
    },
    {
      "Action": [
        "lambda:InvokeFunction",
        "execute-api:Invoke",
        "logs:PutLogEvents",
        "logs:PutLogEventsBatch",
        "logs:CreateLogStream"
      ],
      "Effect": "Allow",
      "Resource": "${aws_lambda_function.auth.arn}"
    }
  ]
}
EOF
}
resource "aws_api_gateway_deployment" "deploy_task_operation" {
  depends_on = [
    aws_api_gateway_integration.get_integration,
    aws_api_gateway_integration.post_integration
    ]

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.api_gw.body))
  }

  rest_api_id = "${aws_api_gateway_rest_api.api_gw.id}"
  stage_name  = "v1"
}

resource "aws_api_gateway_stage" "gw_stage" {
  deployment_id = aws_api_gateway_deployment.deploy_task_operation.id
  rest_api_id   = aws_api_gateway_rest_api.api_gw.id
  stage_name    = var.profile
}


resource "aws_cloudwatch_log_group" "logs" {
  name = "log_group"
}


resource "aws_cloudwatch_log_stream" "log_stream" {
  name           = "LogStream"
  log_group_name = aws_cloudwatch_log_group.logs.name
}


resource "aws_cloudwatch_log_resource_policy" "log_policy" {
  policy_name = "log_policy"

  policy_document = <<CONFIG
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "es.amazonaws.com"
      },
      "Action": [
        "logs:PutLogEvents",
        "logs:PutLogEventsBatch",
        "logs:CreateLogStream"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
CONFIG
}

resource "aws_lambda_permission" "cloudwatch-lambda-permission" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.tasks_function.arn}"
  principal = "logs.${var.region}.amazonaws.com"
  source_arn = "${aws_cloudwatch_log_group.logs.arn}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "log_sbscr" {
  depends_on      = [aws_lambda_permission.cloudwatch-lambda-permission]
  destination_arn = aws_lambda_function.tasks_function.arn
  filter_pattern  = ""
  log_group_name  = aws_cloudwatch_log_group.logs.name
  name            = "logging_default"
}

# MONITORING

# variable "domain" {
#   default = "policy_domain"
# }
# data "aws_region" "current" {}

# data "aws_caller_identity" "current" {}

# resource "aws_elasticsearch_domain" "elastic_search" {
#   domain_name           = "es-domain"
#   elasticsearch_version = "7.10"

#   cluster_config {
#     instance_type = "t3.small.elasticsearch"
#   }

#   ebs_options{
#       ebs_enabled = true
#       volume_size = 5
#   }

#   access_policies = <<POLICY
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Action": "es:*",
#       "Principal": {
#         "AWS": "*"
#       },
#       "Effect": "Allow",
#       "Resource": "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.domain}/*",
#       "Condition": {
#         "IpAddress": {"aws:SourceIp": ["66.193.100.22/32"]}
#       }
#     }
#   ]
# }
# POLICY

#   log_publishing_options {
#     cloudwatch_log_group_arn = aws_cloudwatch_log_group.logs.arn
#     log_type                 = "INDEX_SLOW_LOGS"
#     enabled                  = true
#   }
# }

output "base_url" {
  value = aws_api_gateway_stage.gw_stage.invoke_url
}
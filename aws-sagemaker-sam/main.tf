##################################################
# Local Valuesを使った設定値 　 　　　　　　　　　　　　#
##################################################

# 共有でつける名前
locals {
  prefix_name = "sam-kawagoe-tf"
}

# S3バケット
locals {
  S3_bucket_key    = "SAM_model.tar.gz"          # S3内でのモデルのファイル名
  S3_bucket_source = "./model/SAM_model.tar.gz" # 使用するモデルのローカルパス
}

# Sagemaker
locals {
  sagemaker_image_uri     = "211125561375.dkr.ecr.ap-northeast-1.amazonaws.com/sam-kawagoe-tf-repository:latest" # pushしておいたECRイメージURIに変更
  sagemaker_instance_type = "ml.g4dn.xlarge"                                                                     # sagemakerで使用するインスタンスタイプを指定
}

# Lambda関数
locals {
  lambda_handler  = "lambda_func.lambda_handler"     # ハンドラの設定
  lambda_runtime  = "python3.12"                     # 使用するPythonバージョン
  lambda_filename = "./lambda_func/lambda_func.zip" # ローカルのZIPファイルパス
}


##################################################
# プロバイダー 　　　　　　　　　　　　　　　　　　　　　　#
##################################################

terraform {
  required_version = ">= 1.11.0" # Terraformのバージョンを指定
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.56.0" # AWSプロバイダのバージョンを指定
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}


##################################################
# S3バケット　　　　　　　　　　　　　　　　　　　　　　　#
##################################################

# S3バケット
resource "aws_s3_bucket" "sam_model_bucket" {
  bucket        = "${local.prefix_name}-bucket"
  force_destroy = true # バケット内のオブジェクトが存在する場合でもバケットを削除．これが無いとterraform destroyでS3バケットを削除できない．
  tags          = { Name = "${local.prefix_name}-bucket" }
}

# バケットにモデルをアップロード
resource "aws_s3_object" "object" {
  bucket = aws_s3_bucket.sam_model_bucket.bucket
  key    = local.S3_bucket_key
  source = local.S3_bucket_source

  #ローカルにあるリソースを修正すると、AWS側も連動で更新する
  etag = filemd5(local.S3_bucket_source)
}


##################################################
# model IAM　　　　　　　　　　　　　　　      　　　　 #
##################################################

# SagemakerがS3とECRにアクセスできるようにするrole
resource "aws_iam_role" "sagemaker_role" {
  name = "${local.prefix_name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
      },
    ]
  })
}

# sagemakerとS3へのアクセス権限を与えるポリシーをアタッチ
# AWS提供のマネージドポリシーを使用
resource "aws_iam_role_policy_attachment" "sagemaker_full_access_policy_attach" {
  role       = aws_iam_role.sagemaker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}
resource "aws_iam_role_policy_attachment" "s3_full_access_policy_attach" {
  role       = aws_iam_role.sagemaker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# ECRへのアクセス権限を与えるカスタムポリシーを作成，アタッチ
resource "aws_iam_role_policy" "ecr_full_access_policy" {
  name = "${local.prefix_name}-ecr-full-access"
  role = aws_iam_role.sagemaker_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetDownloadUrlForLayer",     # レイヤーのダウンロードURL取得
          "ecr:BatchGetImage",              # イメージの取得
          "ecr:GetAuthorizationToken",      # 認証トークンの取得
          "ecr:ListImages",                 # イメージ一覧の取得
          "ecr:DescribeRepositories",       # リポジトリ情報の取得
          "ecr:BatchCheckLayerAvailability" # レイヤーの可用性確認
        ],
        Resource = "*" # すべてのECRリソースに対して適用
      }
    ]
  })
}


##################################################
# Sagemaker　　　　　　　　　　　　　　　　　　　　　　　#
##################################################

# SageMaker モデル
resource "aws_sagemaker_model" "sam_model" {
  name               = "${local.prefix_name}-sam-model"
  execution_role_arn = aws_iam_role.sagemaker_role.arn
  primary_container {
    image          = local.sagemaker_image_uri
    model_data_url = "s3://${aws_s3_bucket.sam_model_bucket.bucket}/${local.S3_bucket_key}"
    # 環境変数の追加
    environment = {
      BUCKET_NAME = aws_s3_bucket.sam_model_bucket.bucket # inference.pyで使われる環境変数を指定
    }
  }
}


##################################################
# Sagemaker EndpointConfig　　　　　　　　　　　　　　#
##################################################

# SageMaker エンドポイント設定
resource "aws_sagemaker_endpoint_configuration" "model_endpoint_config" {
  name = "${local.prefix_name}-endpoint-config"

  production_variants {
    variant_name           = "AllTraffic"
    model_name             = aws_sagemaker_model.sam_model.name
    initial_instance_count = 1
    instance_type          = local.sagemaker_instance_type
  }
}


##################################################
# Sagemaker Endpoint      　　　　　　　　　　　　　　#
##################################################

# SageMaker エンドポイントの作成
resource "aws_sagemaker_endpoint" "model_endpoint" {
  name                 = "${local.prefix_name}-endpoint"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.model_endpoint_config.name
}


##################################################
# Lambda IAM　　　　　　　　　　　　　　　　　　　　　　 #
##################################################

# Lambdaに使用するIAMロールの作成
resource "aws_iam_role" "lambda_exec_role" {
  name = "${local.prefix_name}-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com",
        },
      },
    ],
  })
}

# Lambda実行ロールにポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "lambda_exec_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda実行ロールに「Amazon S3 オブジェクトの読み取り専用アクセス権限」を付与
resource "aws_iam_role_policy_attachment" "lambda_s3_readonly" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# Lambda実行ロールにSagemakerエンドポイントへのアクセスを許可
resource "aws_iam_policy" "sagemaker_invoke_policy" {
  name        = "${local.prefix_name}-sagemaker-invoke-policy"
  description = "Policy to allow invoking SageMaker endpoint"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sagemaker:InvokeEndpoint"
        Resource = "arn:aws:sagemaker:ap-northeast-1:211125561375:endpoint/${local.prefix_name}-endpoint"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_invoke_sagemaker" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.sagemaker_invoke_policy.arn
}


##################################################
# Lambda    　　　　　　　　　　　　　　　　　　　　　　 #
##################################################

# Lambda関数の作成
resource "aws_lambda_function" "my_lambda" {
  filename      = local.lambda_filename
  function_name = "${local.prefix_name}-lambda-func"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = local.lambda_handler
  runtime       = local.lambda_runtime
  
  timeout = 120  # タイムアウトを120秒に設定

  source_code_hash = filebase64sha256(local.lambda_filename)

  # 環境変数を設定
  environment {
    variables = {
      BUCKET_NAME       = aws_s3_bucket.sam_model_bucket.tags.Name
      SAM_ENDPOINT_NAME = aws_sagemaker_endpoint.model_endpoint.name
      DEBUG_MODE        = "true"  # デバッグログを有効化
    }
  }
}


##################################################
# API Gateway　　　　　　　　　　　　　　　　　　　　　 #
##################################################

# API GatewayのREST APIを作成
resource "aws_api_gateway_rest_api" "my_api" {
  name        = "${local.prefix_name}-API"
  description = "API for invoking my Lambda function"
}

# API Gatewayのリソースを作成
resource "aws_api_gateway_resource" "my_resource" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  parent_id   = aws_api_gateway_rest_api.my_api.root_resource_id
  path_part   = "invoke_model" # リソースのパス
}

# API Gatewayのメソッドを作成
resource "aws_api_gateway_method" "my_method" {
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  resource_id   = aws_api_gateway_resource.my_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# API GatewayとLambda関数の統合を設定
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.my_api.id
  resource_id             = aws_api_gateway_resource.my_resource.id
  http_method             = aws_api_gateway_method.my_method.http_method
  type                    = "AWS_PROXY" # 統合タイプ
  integration_http_method = "POST"      # 統合で使用するHTTPメソッド
  uri                     = aws_lambda_function.my_lambda.invoke_arn
}

# Lambda関数にAPI Gatewayからのアクセスを許可
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction" # 許可するアクション
  function_name = aws_lambda_function.my_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.my_api.execution_arn}/*/*"
}

# API Gatewayのデプロイメントを定義
resource "aws_api_gateway_deployment" "my_deployment" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id

  depends_on = [aws_api_gateway_integration.lambda_integration]

  # 既存のリソースが有った場合に，一旦削除してから作り直す
  lifecycle {
    create_before_destroy = true
  }
}

# API Gatewayのステージを定義
resource "aws_api_gateway_stage" "gw_stage" {
  deployment_id        = aws_api_gateway_deployment.my_deployment.id
  rest_api_id          = aws_api_gateway_rest_api.my_api.id
  stage_name           = "test"
  description          = "SAM model deploy from terraform"
  xray_tracing_enabled = true # X-Rayトレースの有効化
}

# 既存のステージに対するメソッド設定を構成
resource "aws_api_gateway_method_settings" "settings" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  stage_name  = aws_api_gateway_stage.gw_stage.stage_name
  method_path = "*/*" # 全てのメソッドに適用

  settings {
    logging_level          = "INFO" # ログレベル
    data_trace_enabled     = true   # データトレースの有効化
    metrics_enabled        = true   # メトリクスの有効化
    throttling_burst_limit = 5000   # バースト制限
    throttling_rate_limit  = 10000  # レート制限
  }
}

# CloudWatchロググループを作成
resource "aws_cloudwatch_log_group" "api_gw_log_group" {
  name              = "/aws/api-gateway/${aws_api_gateway_rest_api.my_api.id}"
  retention_in_days = 14 # ログの保存期間
}


##################################################
# Output    　　　 　　　　　　　　　　　　　　　　　　 #
##################################################

output "api_url" {
  value = "${aws_api_gateway_stage.gw_stage.invoke_url}/invoke_model"
}

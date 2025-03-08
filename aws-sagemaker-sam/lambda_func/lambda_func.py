import json
import os
import boto3
import logging

# ログの設定
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# 環境変数
BUCKET_NAME = os.environ.get('BUCKET_NAME')
SAM_ENDPOINT_NAME = os.environ.get('SAM_ENDPOINT_NAME')

# S3リソースを作成
s3 = boto3.resource("s3")

def lambda_handler(event, context):
    """
    Lambda関数のエントリーポイント。

    引数:
        event: トリガーによって提供されるイベントデータ。
        context: ランタイム情報を提供するコンテキストオブジェクト。

    戻り値:
        dict: HTTPステータスコードとレスポンスボディを含む辞書。
    """
    
    # SageMaker runtimeクライアントを作成
    runtime = boto3.client("sagemaker-runtime")
    
    try:
        # eventからボディを取得
        body = json.loads(event['body'])
        
        # SageMakerエンドポイントにリクエストを送信
        response = runtime.invoke_endpoint(
            EndpointName=SAM_ENDPOINT_NAME,  # 使用するSageMakerエンドポイント名
            ContentType="application/json",  # リクエストのコンテンツタイプ
            Accept="application/json",       # レスポンスのコンテンツタイプ
            Body=json.dumps(body),           # ボディデータをJSON文字列に変換して設定
        )
        
        # boto3で呼び出した場合，Bodyをパースする必要がある
        response_body = response["Body"].read().decode('utf-8')  # レスポンスボディを読み取ってパースする
        logger.info("SageMaker response: %s", response_body)  # レスポンスをログに出力
        
        # レスポンスボディをJSONとして返す
        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json"
            },
            "body": response_body  # 既にJSON文字列なのでそのまま返す
        }

    except Exception as e:
        # 例外をログに出力
        logger.error("Error invoking SageMaker endpoint: %s", e, exc_info=True)
        
        # エラーレスポンスを返す
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json"
            },
            "body": json.dumps({
                "message": "Internal server error",
                "error": str(e)
            })
        }
import io
import json
import requests
from PIL import Image
import numpy as np
import datetime
import boto3
import torch
from transformers import SamModel, SamProcessor
import os


# 作成済みのS3バケット
BUCKET_NAME = os.getenv("BUCKET_NAME")

# GPUが使えるなら使う
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

# Initialize the processor with the pre-trained model
processor = SamProcessor.from_pretrained("facebook/sam-vit-base")

def model_fn(model_dir):
    """
    指定されたディレクトリから，事前訓練済みモデルを読み込む．

    引数:
        model_dir (str): 事前訓練済みモデルファイルが含まれるディレクトリ

    戻り値:
        model: 読み込まれた事前訓練済みモデル
    """
    
    print("Executing model_fn from inference.py ...")
    
    
    # モデルの読み込み
    model = SamModel.from_pretrained("facebook/sam-vit-base")
    model.to(device)
    
    # model_fn()の戻り値の型は明確に定義されていない
    # ここでreturnした値がpredict_fn()の第2引数に渡される
    return model

def input_fn(request_body, request_content_type):
    """
    入力データを前処理する．

    引数:
        request_body: リクエストからの入力データ
        request_content_type (str): リクエストのコンテンツタイプ

    戻り値:
        inputs: 前処理された入力データ
    """
    
    print("Executing input_fn from inference.py ...")
    
    
    # 戻り値としてinputsに格納
    inputs = []
    
    if request_content_type == "application/json":
        # json形式のデータを読み込む
        request_body = json.loads(request_body)
        
        # requests.get(url) は、指定された url に対してHTTP GETリクエストを送信し，そのレスポンスを返す．
        # request_body["image_url"] は，JSON形式の request_body から image_url フィールドを取り出す．
        response = requests.get(request_body["image_url"])
        
        # HTTPリクエストのエラーチェック
        response.raise_for_status()
        
        # レスポンスの内容をバイト列として取得し，画像を開く
        img = Image.open(io.BytesIO(response.content))
        
        # 画像の中心を入力ポイントとして定義する．
        input_points = [[[np.array(img.size)/2]]]

        # プロセッサを使用して画像を前処理し，テンソル形式（PyTorchテンソル）に変換する．
        inputs = processor(img, input_points=input_points, return_tensors="pt")
        
        # テンソルを適切なデバイス（CPUやGPU）に移動する．
        inputs = inputs.to(device)
    else:
        raise ValueError(f"Unsupported content type: {request_content_type}")
    
    
    # input_fn()の戻り値の型は明確に定義されていない
    # ここでreturnした値がpredict_fn()の第1引数に渡される
    return inputs

def predict_fn(input_data, model):
    """
    入力データとロードされたモデルを使用して予測を行う．

    引数:
        input_data: 前処理された入力データ
        model: ロードされた事前訓練済みモデル

    戻り値:
        result: 予測結果
    """
    
    print("Executing predict_fn from inference.py ...")
    
    
    # 結果をresultに格納
    result = []
    
    # コンテキストマネージャを使用して，勾配計算を無効にする．これは推論中に必要なメモリ使用量を減らすため．
    with torch.no_grad():
        # モデルを使用して予測を行う
        result = model(**input_data)

        # 予測されたマスクを後処理する
        result = processor.image_processor.post_process_masks(
            result.pred_masks.cpu(), 
            input_data["original_sizes"].cpu(), 
            input_data["reshaped_input_sizes"].cpu()
        )

        if torch.cuda.is_available():
            # GPUキャッシュを空にしてガベージコレクションを行う
            torch.cuda.empty_cache()
            torch.cuda.ipc_collect()
    
    
    return result

def upload_image_to_s3(image, bucket_name):
    """
    画像をS3バケットにアップロードする関数。

    引数:
        image (PIL.Image): アップロードするPIL Imageオブジェクト。
        bucket_name (str): アップロード先のS3バケット名。

    戻り値:
        str: アップロードした画像のS3 URL。
    """
    
    # 一意のファイル名を生成 (現在の日時を使用)
    file_name = f"{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}.jpeg"
    
    # メモリ内のバイトバッファを作成
    img_data = io.BytesIO()
    
    # PIL ImageオブジェクトをJPEG形式でバイトストリームに保存
    image.save(img_data, format='JPEG')
    
    # バイトストリームのポインタを先頭に戻す
    img_data.seek(0)
    
    # S3クライアントを作成
    s3_client = boto3.client('s3')
    
    # バイトストリームを指定されたS3バケットにアップロード
    s3_client.upload_fileobj(img_data, bucket_name, file_name)
    
    # アップロードした画像のS3 URLを生成して返す
    return f"s3://{bucket_name}/{file_name}"

def output_fn(prediction_output, response_content_type):
    """
    予測結果を処理し，レスポンスを準備する．

    引数:
        prediction_output: 予測結果
        content_type (str): レスポンスのコンテンツタイプ

    戻り値:
        str: 指定されたコンテンツタイプでのレスポンス。
    """
    
    print("Executing output_fn from inference.py ...")
    
    
    # masksのコードの解説
    # prediction_outputから最初の要素を取り出し，その中の最初の要素を選択する．これは予測結果のマスクデータ．
    # .numpy()メソッドを使用して，PyTorchテンソルをNumPy配列に変換する．
    # np.transpose を使い，配列の軸を並べ替える．具体的には，軸 [1, 2, 0] の順に並べ替える．これにより，配列の形状が（高さ-幅-チャンネル数）となる．
    # .astype(np.uint8) を使い，配列のデータ型を8ビットの符号なし整数に変換する．
    # 配列の値を255倍して，マスクデータを0〜255の範囲にスケーリングする．これにより，マスクが正しい画像形式になる．
    masks = np.transpose(prediction_output[0][0, :, :, :].numpy(), [1, 2, 0]).astype(np.uint8) * 255
    
    # NumPy配列をPIL Imageに変換
    image = Image.fromarray(masks)
    
    s3_url = upload_image_to_s3(image=image, bucket_name=BUCKET_NAME)
    
    return json.dumps({"s3_url": s3_url}), "application/json"

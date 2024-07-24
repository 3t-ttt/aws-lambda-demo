# requirement definition
AWSBackupのデータをスキャンし、最新のバックアップデータのIDをSystemsManagerのパラメータストアに登録するLambdaが必要
EC2が複数あり、各EC2ごとのバックアップデータを判別する必要がありバックアップデータのタグをもとに判定する処理にする必要がある。
■参考サイト
https://qiita.com/silv224/items/0c1d157d34cd8ffb651b
https://zenn.dev/chittai/articles/20210325-update-ps-for-dr

# policy 
Assuming an IAM role using AWS Security Token Service (STS).
Getting parameters from the AWS Systems Manager Parameter Store.
Putting parameters to the AWS Systems Manager Parameter Store.
Creating log groups and log streams, and putting log events in Amazon CloudWatch Logs.

# EventBridge rule

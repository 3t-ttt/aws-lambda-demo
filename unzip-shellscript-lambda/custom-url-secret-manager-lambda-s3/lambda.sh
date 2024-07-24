#!/bin/bash

# エラーメッセージ
ERROR_MSG="Unknown error occurred."
ERROR_SIGNED_URL="Error: Signed URL not provided."
ERROR_LAMBDA_FUNCTION="Lambda Function Failed"
ERROR_DOWNLOAD_FAILED="Error: Failed to download the files."
ERROR_UNZIP_FAILED="Error: Failed to unzip the file."

# SNSトピックと指定
#TODO: SNS TOPIC ARNを指定
SNS_TOPIC_ARN=""

function main_process() {
    # TODO: バケットを指定
    S3_BUCKET=""
    S3_PATH=""
    S3_PATH_BK=""
    S3_RECEIVE_DIR="s3://$S3_BUCKET$S3_PATH"
    S3_RECEIVE_BACKUP_DIR="s3://$S3_BUCKET$S3_PATH_BK"
    
    # TODO: Seret IDを指定
    SECRET_ID=""

    # Create directory for HTTP code
    HTTP_CODE_DIR="/tmp/http-code"
    mkdir -p "$HTTP_CODE_DIR"

    # Signed URLの取得 
    SECRETS=$(aws secretsmanager get-secret-value --secret-id $SECRET_ID --query SecretString --output text)
    ID=$(echo $SECRETS | sed -n 's/.*"ID":"\([^"]*\)".*/\1/p')
    PASS=$(echo $SECRETS | sed -n 's/.*"PASS":"\([^"]*\)".*/\1/p')
    KEYID=$(echo $SECRETS | sed -n 's/.*"KEYID":"\([^"]*\)".*/\1/p')
    
    SIGNED_URL="https://domain/abcxyz.do?userId=${ID}&pswd=${PASS}&KEYID=${KEYID}"
    echo "Signed URL: $SIGNED_URL"
    
    if [ -z "$SIGNED_URL" ]; then
        printf "%s\n" "${ERROR_SIGNED_URL}"
        ERROR_MSG=$ERROR_SIGNED_URL
        return 1
    fi

    # ファイルのダウンロード
    echo "Downloading file..."
    rm -rf /tmp/download
    mkdir /tmp/download
    cd /tmp/download/
    curl -s -d "userId=${ID}&pswd=${PASS}&interfaceId=${INTERFACEID}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "Accept: application/zip" \
        -O -J \
        -w "%{http_code}" \
        "https://domain/abcxyz.do" \
        > "$HTTP_CODE_DIR/http_code.txt"
    
    http_code=$(<"$HTTP_CODE_DIR/http_code.txt")

    if [ "$http_code" != "200" ]; then
        ERROR_MSG="${ERROR_DOWNLOAD_FAILED} HTTP status code: $http_code"
        return 1
    fi
    
    # ダウンロードされたファイルをログに記録する
    echo "downloaded file: "
    ls -l
    
    # ZIPファイルの解凍
    downloaded_zip=$(ls *.zip)
    FOLDER_NAME=$(basename "$downloaded_zip" .zip)
    rm -rf /tmp/$FOLDER_NAME
    echo "Unzipping file into folder $FOLDER_NAME:"
    mkdir -p "/tmp/$FOLDER_NAME"
    unzip -o -qq "/tmp/download/$downloaded_zip" -d "/tmp/$FOLDER_NAME" >/dev/null || {
        printf "%s\n" "${ERROR_UNZIP_FAILED}"
        ERROR_MSG=$ERROR_UNZIP_FAILED
        return 1
    }
    echo "File unzipped."
    # List extracted files
    echo "unzipped files:"
    ls -l "/tmp/$FOLDER_NAME"
    
    # 解凍されたファイルを受信ディレクトリと受信バックアップディレクトリにアップロード

    txtfile=$(ls "/tmp/$FOLDER_NAME/XXXXXXXX" | head -n 1)
    if [ -n "$txtfile" ]; then
        echo "Found file: $txtfile"
        new_filename="XXXXXXXX.txt"
        datetime=$(TZ=Asia/Tokyo date '+%Y%m%d%H%M%S')
        filename=$(basename "$new_filename" .txt)

        # Rename the file to include .txt extension
        mv "$txtfile" "$txtfile.txt"

        # Upload the file to S3
        aws s3 cp "$txtfile.txt" "$S3_RECEIVE_DIR/$new_filename" >/dev/null || {
            printf "%s\n" "Failed to upload $txtfile.txt to $S3_RECEIVE_DIR!"
            ERROR_MSG="Failed to upload $txtfile.txt to $S3_RECEIVE_DIR!"
            return 1
        }

        aws s3 cp "$txtfile.txt" "$S3_RECEIVE_BACKUP_DIR/${filename}_${datetime}.txt" >/dev/null || {
            printf "%s\n" "Failed to upload $txtfile.txt to $S3_RECEIVE_BACKUP_DIR!"
            ERROR_MSG="Failed to upload $txtfile.txt to $S3_RECEIVE_BACKUP_DIR!"
            return 1
        }

        echo "$new_filename file uploaded to the receive and receive backup directories!"
    else
        echo "No XXXXXXXX file found in the extracted folder!"
        return 1
    fi

}

function handler() {
    main_process || {
        aws sns publish --topic-arn $SNS_TOPIC_ARN --subject "${ERROR_LAMBDA_FUNCTION}" --message "${ERROR_MSG}"
        echo "Error: $ERROR_MSG"
    }
    exit 0
}

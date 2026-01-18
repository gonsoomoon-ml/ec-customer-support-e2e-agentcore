#!/bin/bash

# =============================================================================
# K-Style 이커머스 고객 지원 에이전트 - AWS 환경 설정 스크립트
# AWS CLI 설정 및 필수 서비스 확인
# =============================================================================

set -e
set -o pipefail

echo "☁️ K-Style AWS 환경 설정"
echo "======================="
echo "📅 $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# ----- AWS CLI 설치 확인 -----
echo "🔍 AWS CLI 설치 확인 중..."
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI가 설치되지 않았습니다."
    echo ""
    echo "💡 AWS CLI 설치 방법:"
    echo "   Ubuntu/Debian:"
    echo "     sudo apt update"
    echo "     sudo apt install awscli"
    echo ""
    echo "   또는 최신 버전:"
    echo "     curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\""
    echo "     unzip awscliv2.zip"
    echo "     sudo ./aws/install"
    echo ""
    exit 1
else
    echo "✅ AWS CLI 설치됨: $(aws --version)"
fi

# ----- AWS 자격 증명 확인 -----
echo ""
echo "🔑 AWS 자격 증명 확인 중..."
if aws sts get-caller-identity >/dev/null 2>&1; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    REGION=$(aws configure get region 2>/dev/null || echo "설정되지 않음")
    
    echo "✅ AWS 자격 증명 설정됨"
    echo "   • 계정 ID: $ACCOUNT_ID"
    echo "   • 사용자/역할: $USER_ARN"
    echo "   • 기본 리전: $REGION"
    
    if [ "$REGION" = "설정되지 않음" ]; then
        echo ""
        echo "⚠️ 기본 리전이 설정되지 않았습니다."
        read -p "🌍 사용할 AWS 리전을 입력하세요 (예: us-east-1): " input_region
        if [ ! -z "$input_region" ]; then
            aws configure set region "$input_region"
            echo "✅ 리전이 $input_region 으로 설정되었습니다."
            REGION="$input_region"
        fi
    fi
else
    echo "❌ AWS 자격 증명이 설정되지 않았습니다."
    echo ""
    echo "💡 AWS 자격 증명 설정 방법:"
    echo "   aws configure"
    echo ""
    echo "   필요한 정보:"
    echo "   • AWS Access Key ID"
    echo "   • AWS Secret Access Key"
    echo "   • Default region name (예: us-east-1)"
    echo "   • Default output format (json 권장)"
    echo ""
    exit 1
fi

# ----- 필수 AWS 서비스 권한 확인 (deploy.sh 포함) -----
echo ""
echo "🛡️ AWS 서비스 권한 확인 중..."

failed_services=()

# STS
if aws sts get-caller-identity >/dev/null 2>&1; then
    echo "✅ sts:GetCallerIdentity"
else
    echo "❌ sts:GetCallerIdentity"
    failed_services+=("sts")
fi

# S3
if aws s3 ls >/dev/null 2>&1; then
    echo "✅ s3:ListBuckets"
else
    echo "❌ s3:ListBuckets"
    failed_services+=("s3")
fi

# CloudFormation
if aws cloudformation list-stacks --region $REGION >/dev/null 2>&1; then
    echo "✅ cloudformation:ListStacks"
else
    echo "❌ cloudformation:ListStacks"
    failed_services+=("cloudformation")
fi

# IAM
if aws iam list-roles --max-items 1 >/dev/null 2>&1; then
    echo "✅ iam:ListRoles"
else
    echo "❌ iam:ListRoles"
    failed_services+=("iam")
fi

# Lambda
if aws lambda list-functions --region $REGION --max-items 1 >/dev/null 2>&1; then
    echo "✅ lambda:ListFunctions"
else
    echo "❌ lambda:ListFunctions"
    failed_services+=("lambda")
fi

# DynamoDB
if aws dynamodb list-tables --region $REGION --max-items 1 >/dev/null 2>&1; then
    echo "✅ dynamodb:ListTables"
else
    echo "❌ dynamodb:ListTables"
    failed_services+=("dynamodb")
fi

# Cognito
if aws cognito-idp list-user-pools --region $REGION --max-results 1 >/dev/null 2>&1; then
    echo "✅ cognito-idp:ListUserPools"
else
    echo "❌ cognito-idp:ListUserPools"
    failed_services+=("cognito-idp")
fi

if [ ${#failed_services[@]} -ne 0 ]; then
    echo ""
    echo "⚠️ 일부 서비스에 대한 권한이 없습니다:"
    for service in "${failed_services[@]}"; do
        echo "   • $service"
    done
    echo ""
    echo "💡 deploy.sh 실행에 필요한 IAM 권한:"
    echo "   • cloudformation:*"
    echo "   • iam:*"
    echo "   • s3:*"
    echo "   • lambda:*"
    echo "   • dynamodb:*"
    echo "   • ssm:*"
    echo "   • cognito-idp:*"
    echo ""
    echo "   권장: AdministratorAccess 정책 사용"
    echo ""
fi

# ----- 환경 설정 요약 -----
echo ""
echo "📋 AWS 환경 설정 요약"
echo "==================="
echo "✅ AWS CLI: 설치됨"
echo "✅ 자격 증명: 설정됨 ($ACCOUNT_ID)"
echo "✅ 기본 리전: $REGION"

if [ ${#failed_services[@]} -eq 0 ]; then
    echo "✅ 서비스 권한: 모두 확인됨"
else
    echo "⚠️ 서비스 권한: 일부 제한됨 (${#failed_services[@]}개)"
fi

echo ""
echo "🚀 다음 단계:"
echo "   1. 인프라 배포 (CloudFormation):"
echo "      ./setup/deploy_infra.sh"
echo ""
echo "   2. 노트북 실행:"
echo "      notebooks/lab-01-create-ecommerce-agent.ipynb 열기"
echo "      커널 선택: ecommerce-agent"
echo ""

if [ ${#failed_services[@]} -ne 0 ]; then
    echo "⚠️ 주의: 일부 권한이 제한되어 있어 기능이 제한될 수 있습니다."
    echo "   관리자에게 필요한 IAM 권한을 요청하세요."
    echo ""
fi

echo "☁️ AWS 환경 설정 확인 완료!"
#!/bin/sh
# =============================================================================
# K-Style E-Commerce Infrastructure Deployment Script
# =============================================================================
#
# 이 스크립트는 K-Style 이커머스 고객 지원 시스템의 AWS 인프라를 배포합니다.
#
# 배포 리소스:
#   - S3 버킷 (Lambda 코드 저장)
#   - Lambda 함수 (고객 지원 도구)
#   - Lambda Layer (DDGS 패키지)
#   - DynamoDB 테이블 (고객/보증 데이터)
#   - IAM 역할 (AgentCore Runtime/Gateway)
#   - Cognito User Pool (인증)
#   - SSM Parameters (설정값)
#
# 사용법:
#   ./setup/deploy_infra.sh [BUCKET_NAME] [INFRA_STACK] [COGNITO_STACK]
#
# 예시:
#   ./setup/deploy_infra.sh                    # 기본값 사용
#   ./setup/deploy_infra.sh mycompany          # 커스텀 버킷 이름
#
# 사전 요구사항:
#   - AWS CLI 설정 완료 (aws configure)
#   - Python 가상환경 활성화 (source setup/.venv/bin/activate)
#   - 필요 IAM 권한: CloudFormation, S3, Lambda, DynamoDB, IAM, Cognito, SSM
#
# =============================================================================

set -e  # 오류 발생 시 즉시 중단

# ----- 스크립트 디렉토리 확인 -----
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ----- 설정값 -----
BUCKET_NAME=${1:-ecommercesupport112}
INFRA_STACK_NAME=${2:-EcommerceCustomerSupportStackInfra}
COGNITO_STACK_NAME=${3:-EcommerceCustomerSupportStackCognito}
INFRA_TEMPLATE_FILE="$SCRIPT_DIR/cloudformation/infrastructure.yaml"
COGNITO_TEMPLATE_FILE="$SCRIPT_DIR/cloudformation/cognito.yaml"
LAMBDA_SRC="$SCRIPT_DIR/lambda"
REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
FULL_BUCKET_NAME="${BUCKET_NAME}-${ACCOUNT_ID}-${REGION}"
ZIP_FILE="lambda.zip"
LAYER_ZIP_FILE="ddgs-layer.zip"
S3_KEY="${ZIP_FILE}"
S3_LAYER_KEY="${LAYER_ZIP_FILE}"

echo "============================================="
echo "🚀 K-Style 인프라 배포 시작"
echo "============================================="
echo "📍 Region: $REGION"
echo "🔑 Account ID: $ACCOUNT_ID"
echo "🪣 S3 Bucket: $FULL_BUCKET_NAME"
echo ""

# ----- 1. S3 버킷 생성 -----
echo "📦 [1/5] S3 버킷 생성 중..."
if [ "$REGION" = "us-east-1" ]; then
  aws s3api create-bucket \
    --bucket "$FULL_BUCKET_NAME" \
    2>/dev/null || echo "   ℹ️ 버킷이 이미 존재합니다."
else
  aws s3api create-bucket \
    --bucket "$FULL_BUCKET_NAME" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION" \
    2>/dev/null || echo "   ℹ️ 버킷이 이미 존재합니다."
fi
echo "   ✅ S3 버킷 준비 완료"
echo ""

# ----- 2. Lambda 코드 패키징 -----
echo "📦 [2/5] Lambda 코드 패키징 중..."
which zip > /dev/null || sudo apt install -y zip
WORK_DIR=$(pwd)
cd "$LAMBDA_SRC"
zip -r "$WORK_DIR/$ZIP_FILE" . > /dev/null
cd "$WORK_DIR"
echo "   ✅ Lambda 코드 압축 완료: $ZIP_FILE"
echo ""

# ----- 3. Lambda Layer 생성 (DDGS 패키지) -----
echo "📦 [3/5] DDGS Lambda Layer 생성 중..."
LAYER_DIR=$(mktemp -d)
mkdir -p "$LAYER_DIR/python"
python3 -m pip install ddgs -t "$LAYER_DIR/python" --quiet
cd "$LAYER_DIR"
zip -r "$WORK_DIR/$LAYER_ZIP_FILE" python > /dev/null
cd "$WORK_DIR"
rm -rf "$LAYER_DIR"
echo "   ✅ Lambda Layer 생성 완료: $LAYER_ZIP_FILE"
echo ""

# ----- 4. S3 업로드 -----
echo "☁️ [4/5] S3에 파일 업로드 중..."
aws s3 cp "$ZIP_FILE" "s3://$FULL_BUCKET_NAME/$S3_KEY" --quiet
echo "   ✅ $ZIP_FILE 업로드 완료"
aws s3 cp "$LAYER_ZIP_FILE" "s3://$FULL_BUCKET_NAME/$S3_LAYER_KEY" --quiet
echo "   ✅ $LAYER_ZIP_FILE 업로드 완료"

# 로컬 zip 파일 정리
rm -f "$ZIP_FILE" "$LAYER_ZIP_FILE"
echo ""

# ----- 5. CloudFormation 스택 배포 -----
echo "🏗️ [5/5] CloudFormation 스택 배포 중..."

deploy_stack() {
  set +e  # 이 함수 내에서는 오류 시 계속 진행 (직접 처리)

  local stack_name=$1
  local template_file=$2
  shift 2

  echo ""
  echo "   🚀 $stack_name 배포 중..."

  output=$(aws cloudformation deploy \
    --stack-name "$stack_name" \
    --template-file "$template_file" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$REGION" \
    "$@" 2>&1)

  exit_code=$?

  if [ $exit_code -ne 0 ]; then
    if echo "$output" | grep -qi "No changes to deploy"; then
      echo "   ℹ️ $stack_name: 변경사항 없음"
      return 0
    else
      echo "   ❌ $stack_name 배포 실패:"
      echo "$output"
      return $exit_code
    fi
  else
    echo "   ✅ $stack_name 배포 완료"
    return 0
  fi
}

# Infrastructure 스택 배포
deploy_stack "$INFRA_STACK_NAME" "$INFRA_TEMPLATE_FILE" \
  --parameter-overrides \
  LambdaS3Bucket="$FULL_BUCKET_NAME" \
  LambdaS3Key="$S3_KEY" \
  LayerS3Key="$S3_LAYER_KEY"

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Infrastructure 스택 배포 실패. 배포를 중단합니다."
    exit 1
fi

# Cognito 스택 배포
deploy_stack "$COGNITO_STACK_NAME" "$COGNITO_TEMPLATE_FILE"

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Cognito 스택 배포 실패. 배포를 중단합니다."
    exit 1
fi

echo ""
echo "============================================="
echo "✅ 인프라 배포 완료!"
echo "============================================="
echo ""
echo "🚀 다음 단계:"
echo "   notebooks/lab-01-create-ecommerce-agent.ipynb 열기"
echo "   커널 선택: ecommerce-agent"
echo ""

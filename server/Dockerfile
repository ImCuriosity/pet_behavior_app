# Dockerfile

# 1. Python 공식 이미지 중 슬림 버전 사용 (용량 절약)
FROM python:3.11-slim

# 2. 작업 디렉토리 설정
WORKDIR /app

# 3. 환경 변수 설정 (Uvicorn 포트와 호스트 설정)
# Cloud Run은 0.0.0.0 호스트와 $PORT 환경 변수에서 지정하는 포트를 사용해야 합니다.
# 이 ENV는 로컬 테스트 시 기본값을 제공하며, Cloud Run에서는 런타임에 주입되는 값으로 덮어쓰여집니다.
ENV PORT=8080 
ENV HOST=0.0.0.0

# 4. 의존성 설치 (캐싱을 위해 requirements.txt를 먼저 복사)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 5. ML 모델 가중치 및 Python 코드 복사
# 모델 파일(예: model_weights.pkl, model_weights.joblib 등)이 있다면 여기에 포함
COPY . .

# 6. 컨테이너가 실행될 때 실행될 명령어 정의
# ⭐️ [수정] exec 형식("[]") 대신 shell 형식을 사용하여 $PORT 환경 변수를 올바르게 인식하도록 합니다.
CMD uvicorn main:app --host 0.0.0.0 --port $PORT

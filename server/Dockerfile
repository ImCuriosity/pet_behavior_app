# Dockerfile

# 1. 베이스 이미지 선택
FROM python:3.9

# 2. 작업 디렉토리 설정
WORKDIR /app

# 3. 의존성 설치 (이 부분은 빌드 캐시를 활용하여 더 빠르게 실행됩니다)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 4. 소스 코드 복사
COPY . .

# ✨ [추가] 5. 서버 실행 명령어!
# Cloud Run이 제공하는 PORT 환경 변수를 사용하여 8080 포트에서
# main.py 파일 안에 있는 app 변수(FastAPI 인스턴스)를 실행합니다.
CMD ["gunicorn", "-w", "4", "-k", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:8080", "main:app"]

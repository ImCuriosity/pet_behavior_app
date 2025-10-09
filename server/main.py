import os
import random
import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI, UploadFile, File, HTTPException, Form, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from jose import jwt, JWTError
from supabase import create_client, Client
import vertexai
from vertexai.generative_models import GenerativeModel

# -----------------------------------------------------
# 1. Lifespan 이벤트 핸들러 및 전역 변수
# -----------------------------------------------------

gemini_model = None
supabase_client: Client = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    # === 서버 시작 시 실행될 로직 ===
    global gemini_model, supabase_client
    print("🚀 Initializing application lifespan...")

    # 1. Supabase 클라이언트 초기화
    try:
        supabase_url = os.environ.get("SUPABASE_URL")
        supabase_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
        if not supabase_url or not supabase_key:
            raise ValueError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set.")
        supabase_client = create_client(supabase_url, supabase_key)
        print("✅ Supabase client initialized successfully.")
    except Exception as e:
        print(f"🚨 FATAL: Failed to initialize Supabase client: {e}")
        supabase_client = None

    # 2. Vertex AI 클라이언트 초기화
    try:
        # ✨ [수정] 모델 가용성이 높은 'us-central1' 리전으로 변경
        print("Attempting to initialize Vertex AI client in us-central1...")
        vertexai.init(location="us-central1")

        # ✨ [수정] 모델을 'gemini-2.5-flash'로 변경 (이전 gemini-pro 대신)
        gemini_model = GenerativeModel("gemini-2.5-flash")
        print("✅ Vertex AI client initialized successfully with gemini-2.5-flash.")
    except Exception as e:
        print(f"🚨 FATAL: Failed to initialize Vertex AI client: {e}")
        gemini_model = None

    print("✨ Application startup complete.")
    yield
    # === 서버 종료 시 실행될 로직 (현재는 없음) ===
    print("👋 Application shutdown.")

# -----------------------------------------------------
# 2. FastAPI 앱 생성 및 미들웨어 설정
# -----------------------------------------------------

app = FastAPI(title="Pet Behavior Analysis API", version="1.8.0", lifespan=lifespan)

# ✨ [수정] ngrok에서의 접속을 허용하기 위해 모든 주소(origins)를 허용합니다.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # localhost만 허용하던 것에서 모든 주소를 허용하도록 변경
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -----------------------------------------------------
# 3. 사용자 인증
# -----------------------------------------------------

SUPABASE_JWT_SECRET = os.environ.get("SUPABASE_JWT_SECRET")
security_scheme = HTTPBearer()

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security_scheme)) -> dict:
    if not SUPABASE_JWT_SECRET: raise HTTPException(500, "JWT secret not configured.")
    try:
        token = credentials.credentials
        return jwt.decode(token, SUPABASE_JWT_SECRET, algorithms=["HS256"], audience="authenticated")
    except JWTError as e:
        raise HTTPException(401, f"Invalid or expired token: {e}")

# -----------------------------------------------------
# 4. 가짜 분석 모델 (변경 없음)
# -----------------------------------------------------
def get_sound_analysis_result(audio_file: UploadFile): return {"positive_score": random.uniform(0.1, 0.9), "active_score": random.uniform(0.3, 0.9)}
def get_facial_expression_result(image_file: UploadFile): return {"positive_score": random.uniform(0.2, 0.8), "active_score": random.uniform(0.1, 0.5)}
def get_body_language_result(image_file: UploadFile): return {"positive_score": random.uniform(0.3, 0.9), "active_score": random.uniform(0.2, 0.8)}
def get_eeg_result(eeg_file: UploadFile): return {"positive_score": random.uniform(0.1, 0.6), "active_score": random.uniform(0.1, 0.4)}

# -----------------------------------------------------
# 5. 동기 방식으로 동작하는 DB 저장 함수
# -----------------------------------------------------
def sync_save_analysis_to_db(user_id: str, dog_id: str, analysis_type: str, model_result: dict):
    if not supabase_client:
        print("🔥 DB Save Error: Supabase client not initialized. Cannot save to DB.")
        return
    try:
        data_to_insert = {
            "user_id": user_id,
            "dog_id": dog_id,
            "analysis_type": analysis_type,
            "positive_score": model_result.get("positive_score"),
            "active_score": model_result.get("active_score"),
        }
        print(f"📦 Attempting to insert into DB: {data_to_insert}")
        response = supabase_client.table("analysis_results").insert(data_to_insert).execute()
        print(f"✅ Successfully saved analysis to DB for user {user_id}. Response: {response.data}")
    except Exception as e:
        print(f"🔥 DB Save Error: {e}")

# -----------------------------------------------------
# 6. API 엔드포인트
# -----------------------------------------------------

async def run_analysis_and_save(user_id: str, dog_id: str, analysis_type: str, analysis_func, file):
    model_result = analysis_func(file)
    await asyncio.to_thread(sync_save_analysis_to_db, user_id, dog_id, analysis_type, model_result)
    return {"status": "success", "dog_id": dog_id, **model_result}

@app.post("/api/v1/ml/analyze_sound")
async def analyze_sound_endpoint(dog_id: str = Form(...), audio_file: UploadFile = File(...), user: dict = Depends(get_current_user)):
    return await run_analysis_and_save(user.get('sub'), dog_id, "sound", get_sound_analysis_result, audio_file)

@app.post("/api/v1/ml/analyze_facial_expression")
async def analyze_facial_expression_endpoint(dog_id: str = Form(...), image_file: UploadFile = File(...), user: dict = Depends(get_current_user)):
    return await run_analysis_and_save(user.get('sub'), dog_id, "facial_expression", get_facial_expression_result, image_file)

@app.post("/api/v1/ml/analyze_body_language")
async def analyze_body_language_endpoint(dog_id: str = Form(...), image_file: UploadFile = File(...), user: dict = Depends(get_current_user)):
    return await run_analysis_and_save(user.get('sub'), dog_id, "body_language", get_body_language_result, image_file)

@app.post("/api/v1/ml/analyze_eeg")
async def analyze_eeg_endpoint(dog_id: str = Form(...), eeg_file: UploadFile = File(...), user: dict = Depends(get_current_user)):
    return await run_analysis_and_save(user.get('sub'), dog_id, "eeg", get_eeg_result, eeg_file)

@app.post("/api/v1/chatbot/query")
async def get_chatbot_response_endpoint(request_data: dict, user: dict = Depends(get_current_user)):
    user_query = request_data.get("query")
    if not user_query: raise HTTPException(400, "Query is missing.")
    if not gemini_model: raise HTTPException(503, "Chatbot model not available.")
    try:
        # ✨ [수정] 챗봇의 역할을 명확히 하고, 항상 한국어로 답변하도록 프롬프트 수정
        prompt = f"You are a helpful and friendly dog behavior expert. Always answer in Korean. User query: '{user_query}'"
        response = await gemini_model.generate_content_async(prompt)
        return {"user_id": user.get('sub'), "response": response.text}
    except Exception as e:
        # Vertex AI 호출 실패 시 에러 상세 정보 출력
        print(f"🚨 Vertex AI call failed with exception: {e}")
        # 이전 404 에러의 재발 방지를 위해 500 에러를 반환
        raise HTTPException(500, f"Vertex AI call failed: {e}")

@app.get("/")
def health_check():
    return {"status": "ok", "service": "Pet Analysis API is running!"}

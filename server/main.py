# main.py (FastAPI 서버 로직 - 모든 기능 복원)

import os
import random
from fastapi import FastAPI, UploadFile, File, HTTPException, Form, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from jose import jwt, JWTError

import vertexai
from vertexai.generative_models import GenerativeModel

# ----------------------------------------------------
# 1. FastAPI 인스턴스, 환경 변수, 전역 변수 설정
# ----------------------------------------------------

app = FastAPI(title="Pet Behavior Analysis API", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"],)

SUPABASE_JWT_SECRET = os.environ.get("SUPABASE_JWT_SECRET")
gemini_model = None
security_scheme = HTTPBearer()

# ----------------------------------------------------
# 2. 서버 시작 시 초기화 로직
# ----------------------------------------------------

@app.on_event("startup")
def load_and_initialize():
    global gemini_model
    print("Initializing FastAPI Application with Vertex AI (Gemini 2.5 Flash)...")
    try:
        vertexai.init(project=os.environ.get("GCP_PROJECT"), location="us-central1")
        gemini_model = GenerativeModel("gemini-2.5-flash")
        print("✅ Vertex AI Gemini 2.5 Flash model initialized successfully.")
    except Exception as e:
        print(f"🚨 FATAL: Failed to initialize Vertex AI client: {e}")
    if not SUPABASE_JWT_SECRET:
        print("🚨 FATAL: SUPABASE_JWT_SECRET is not set. Authentication will fail.")

# ----------------------------------------------------
# ✨ [추가] 3. 가짜 분석 모델 (나중에 실제 모델로 교체될 부분)
# ----------------------------------------------------

def get_sound_analysis_result(audio_file: UploadFile):
    print(f"Analyzing sound file: {audio_file.filename} (mock)")
    return {"positive_score": random.uniform(0.1, 0.9), "active_score": random.uniform(0.3, 0.9)}

def get_facial_expression_result(image_file: UploadFile):
    print(f"Analyzing facial expression in: {image_file.filename} (mock)")
    return {"positive_score": random.uniform(0.2, 0.8), "active_score": random.uniform(0.1, 0.5)}

def get_body_language_result(image_file: UploadFile):
    print(f"Analyzing body language in: {image_file.filename} (mock)")
    return {"positive_score": random.uniform(0.3, 0.9), "active_score": random.uniform(0.2, 0.8)}

def get_eeg_result(eeg_file: UploadFile):
    print(f"Analyzing EEG file: {eeg_file.filename} (mock)")
    return {"positive_score": random.uniform(0.1, 0.6), "active_score": random.uniform(0.1, 0.4)}

# ----------------------------------------------------
# 4. 사용자 인증 (JWT 검증) 함수
# ----------------------------------------------------

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security_scheme)) -> dict:
    token = credentials.credentials
    if not SUPABASE_JWT_SECRET:
        raise HTTPException(status_code=500, detail="Server configuration error: JWT secret not set.")
    try:
        payload = jwt.decode(token, SUPABASE_JWT_SECRET, algorithms=["HS256"], audience="authenticated")
        return payload
    except JWTError as e:
        raise HTTPException(status_code=401, detail=f"Invalid or expired token: {e}", headers={"WWW-Authenticate": "Bearer"})
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred during token validation: {e}")

# ----------------------------------------------------
# ✨ [수정] 5. ML 분석 엔드포인트들이 가짜 모델 함수를 호출하도록 변경
# ----------------------------------------------------

@app.post("/api/v1/ml/analyze_sound", dependencies=[Depends(get_current_user)])
async def analyze_sound_endpoint(dog_id: str = Form(...), audio_file: UploadFile = File(...)):
    model_result = get_sound_analysis_result(audio_file)
    return {"status": "success", "dog_id": dog_id, **model_result}

@app.post("/api/v1/ml/analyze_facial_expression", dependencies=[Depends(get_current_user)])
async def analyze_facial_expression_endpoint(dog_id: str = Form(...), image_file: UploadFile = File(...)):
    model_result = get_facial_expression_result(image_file)
    return {"status": "success", "dog_id": dog_id, **model_result}

@app.post("/api/v1/ml/analyze_body_language", dependencies=[Depends(get_current_user)])
async def analyze_body_language_endpoint(dog_id: str = Form(...), image_file: UploadFile = File(...)):
    model_result = get_body_language_result(image_file)
    return {"status": "success", "dog_id": dog_id, **model_result}

@app.post("/api/v1/ml/analyze_eeg", dependencies=[Depends(get_current_user)])
async def analyze_eeg_endpoint(dog_id: str = Form(...), eeg_file: UploadFile = File(...)):
    model_result = get_eeg_result(eeg_file)
    return {"status": "success", "dog_id": dog_id, **model_result}

# ----------------------------------------------------
# 6. 엔드포인트: RAG 챗봇 (Gemini 모델 사용)
# ----------------------------------------------------

@app.post("/api/v1/chatbot/query")
async def get_chatbot_response_endpoint(request_data: dict, current_user: dict = Depends(get_current_user)):
    global gemini_model
    user_query = request_data.get("query")
    user_id = current_user.get('sub')

    if not user_query:
        raise HTTPException(status_code=400, detail="Missing 'query' field.")
    if not gemini_model:
        raise HTTPException(status_code=503, detail="Vertex AI model is not available.")

    try:
        prompt = f"You are a friendly and helpful expert on dog behavior. A user with ID '{user_id}' is asking a question. Here is their question: '{user_query}'. Provide a concise and helpful answer."
        response = await gemini_model.generate_content_async(prompt)
        return {"user_id": user_id, "response": response.text}
    except Exception as e:
        print(f"🔥 Vertex AI Gemini API Error: {e}")
        raise HTTPException(status_code=500, detail=f"Vertex AI call failed: {e}")

# ... (Health Check 엔드포인트는 변경 없음) ...
@app.get("/")
def health_check():
    return {"status": "ok", "service": "FastAPI ML Backend"}

import os
import random
import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI, UploadFile, File, HTTPException, Form, Depends, Query
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from jose import jwt, JWTError
from supabase import create_client, Client
import vertexai
from vertexai.generative_models import GenerativeModel
from typing import Optional, List
import datetime

# Globals
gemini_model = None
supabase_client: Client = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    print("✅ Dognal API is booting...")
    global gemini_model, supabase_client
    try:
        supabase_url = os.environ.get("SUPABASE_URL")
        supabase_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
        if not supabase_url or not supabase_key: raise ValueError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set.")
        supabase_client = create_client(supabase_url, supabase_key)
        print("✅ Supabase client initialized successfully.")
    except Exception as e:
        print(f"🚨 FATAL: Failed to initialize Supabase client: {e}")
        supabase_client = None
    try:
        print("Attempting to initialize Vertex AI client...")
        vertexai.init(location="us-central1")
        gemini_model = GenerativeModel("gemini-2.5-flash")
        print("✅ Vertex AI client initialized successfully.")
    except Exception as e:
        print(f"🚨 FATAL: Failed to initialize Vertex AI client: {e}")
        gemini_model = None
    
    print("✨ Application startup complete.")
    yield
    print("👋 Application shutdown.")

app = FastAPI(title="Dognal API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Auth ---
SUPABASE_JWT_SECRET = os.environ.get("SUPABASE_JWT_SECRET")
security_scheme = HTTPBearer()
async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security_scheme)) -> dict:
    if not SUPABASE_JWT_SECRET: raise HTTPException(500, "JWT secret not configured.")
    try:
        return jwt.decode(credentials.credentials, SUPABASE_JWT_SECRET, algorithms=["HS256"], audience="authenticated")
    except JWTError as e:
        raise HTTPException(401, f"Invalid or expired token: {e}")

# --- Fake ML Models ---
def get_sound_analysis_result(audio_file: UploadFile): return {"positive_score": random.uniform(0.1, 0.9), "active_score": random.uniform(0.3, 0.9)}
def get_facial_expression_result(image_file: UploadFile): return {"positive_score": random.uniform(0.2, 0.8), "active_score": random.uniform(0.1, 0.5)}
def get_body_language_result(image_file: UploadFile): return {"positive_score": random.uniform(0.3, 0.9), "active_score": random.uniform(0.2, 0.8)}
def get_eeg_result(eeg_file: UploadFile): return {"positive_score": random.uniform(0.1, 0.6), "active_score": random.uniform(0.1, 0.4)}

# --- DB Functions ---
def sync_save_analysis_to_db(user_id: str, dog_id: str, analysis_type: str, model_result: dict, activity_description: Optional[str] = None):
    if not supabase_client: return
    try: supabase_client.table("analysis_results").insert({"user_id": user_id, "dog_id": dog_id, "analysis_type": analysis_type, "positive_score": model_result.get("positive_score"), "active_score": model_result.get("active_score"), "activity_description": activity_description}).execute()
    except Exception as e: print(f"🔥 DB Save Error: {e}")

def sync_get_rag_analysis_data(user_id: str, dog_id: str, view_type: str) -> List[dict]:
    if not supabase_client: return []
    try:
        kst = datetime.timezone(datetime.timedelta(hours=9))
        today_kst = datetime.datetime.now(kst).date()

        if view_type == 'daily':
            start_dt = datetime.datetime.combine(today_kst, datetime.time.min, tzinfo=kst)
            end_dt = datetime.datetime.combine(today_kst, datetime.time.max, tzinfo=kst)
        elif view_type == 'weekly':
            start_of_week = today_kst - datetime.timedelta(days=today_kst.weekday())
            end_of_week = start_of_week + datetime.timedelta(days=6)
            start_dt = datetime.datetime.combine(start_of_week, datetime.time.min, tzinfo=kst)
            end_dt = datetime.datetime.combine(end_of_week, datetime.time.max, tzinfo=kst)
        else:
            return []

        response = supabase_client.table("analysis_results") \
            .select("created_at, positive_score, active_score, activity_description") \
            .eq("user_id", user_id) \
            .eq("dog_id", dog_id) \
            .gte("created_at", start_dt.isoformat()) \
            .lte("created_at", end_dt.isoformat()) \
            .order("created_at", desc=True).execute()
        return response.data
    except Exception as e:
        print(f"🔥 RAG DB-Read Error (view_type: {view_type}): {e}")
        return []

def sync_get_diary(user_id: str, dog_id: str, diary_date: str) -> Optional[dict]:
    if not supabase_client: return None
    try: return supabase_client.table("diaries").select("content").eq("user_id", user_id).eq("dog_id", dog_id).eq("diary_date", diary_date).single().execute().data
    except Exception: return None

def sync_save_diary(user_id: str, dog_id: str, diary_date: str, content: str) -> Optional[dict]:
    if not supabase_client: return None
    try: return supabase_client.table("diaries").insert({"user_id": user_id, "dog_id": dog_id, "diary_date": diary_date, "content": content}).execute().data[0]
    except Exception as e: print(f"🔥 Diary Save Error: {e}"); return None

def sync_get_analysis_for_diary(user_id: str, dog_id: str, target_date: datetime.date) -> List[dict]:
    if not supabase_client: return []
    try:
        kst = datetime.timezone(datetime.timedelta(hours=9)); start_of_day = datetime.datetime.combine(target_date, datetime.time.min, tzinfo=kst); end_of_day = datetime.datetime.combine(target_date, datetime.time.max, tzinfo=kst)
        return supabase_client.table("analysis_results").select("*").eq("user_id", user_id).eq("dog_id", dog_id).gte("created_at", start_of_day.isoformat()).lte("created_at", end_of_day.isoformat()).order("created_at").execute().data
    except Exception as e: print(f"🔥 Diary Analysis Read Error: {e}"); return []

# --- API Endpoints ---

async def run_analysis_and_save(user_id: str, dog_id: str, analysis_type: str, analysis_func, file, activity_description: Optional[str] = None):
    model_result = analysis_func(file); await asyncio.to_thread(sync_save_analysis_to_db, user_id, dog_id, analysis_type, model_result, activity_description); return {"status": "success", "dog_id": dog_id, **model_result}

@app.post("/api/v1/ml/analyze_sound")
async def analyze_sound_endpoint(dog_id: str = Form(...), audio_file: UploadFile = File(...), user: dict = Depends(get_current_user), activity_description: Optional[str] = Form(None)): return await run_analysis_and_save(user.get('sub'), dog_id, "sound", get_sound_analysis_result, audio_file, activity_description)

@app.post("/api/v1/ml/analyze_facial_expression")
async def analyze_facial_expression_endpoint(dog_id: str = Form(...), image_file: UploadFile = File(...), user: dict = Depends(get_current_user), activity_description: Optional[str] = Form(None)): return await run_analysis_and_save(user.get('sub'), dog_id, "facial_expression", get_facial_expression_result, image_file, activity_description)

@app.post("/api/v1/ml/analyze_body_language")
async def analyze_body_language_endpoint(dog_id: str = Form(...), image_file: UploadFile = File(...), user: dict = Depends(get_current_user), activity_description: Optional[str] = Form(None)): return await run_analysis_and_save(user.get('sub'), dog_id, "body_language", get_body_language_result, image_file, activity_description)

@app.post("/api/v1/ml/analyze_eeg")
async def analyze_eeg_endpoint(dog_id: str = Form(...), eeg_file: UploadFile = File(...), user: dict = Depends(get_current_user), activity_description: Optional[str] = Form(None)): return await run_analysis_and_save(user.get('sub'), dog_id, "eeg", get_eeg_result, eeg_file, activity_description)

@app.get("/api/v1/diary/{dog_id}")
async def get_or_create_diary_entry(dog_id: str, diary_date_str: str = Query(..., alias="diaryDate"), user: dict = Depends(get_current_user)):
    user_id = user.get('sub')
    try: target_date = datetime.datetime.strptime(diary_date_str, "%Y-%m-%d").date()
    except ValueError: raise HTTPException(400, "Invalid date format. Please use YYYY-MM-DD.")
    existing_diary = await asyncio.to_thread(sync_get_diary, user_id, dog_id, diary_date_str)
    if existing_diary and existing_diary.get("content"): return {"content": existing_diary["content"], "status": "exists"}
    kst = datetime.timezone(datetime.timedelta(hours=9)); today_kst = datetime.datetime.now(kst).date()
    if target_date < today_kst: return {"content": "이날은 왠지 일기를 깜빡했나 봐요. 주인님이랑 노는 게 더 좋았나?", "status": "past_empty"}
    if target_date > today_kst: return {"content": "아직 오지 않은 미래의 일기는 쓸 수 없어요!", "status": "future_empty"}
    if target_date == today_kst:
        todays_analysis = await asyncio.to_thread(sync_get_analysis_for_diary, user_id, dog_id, target_date)
        if not todays_analysis: return {"content": "오늘은 아직 주인님이랑 있었던 일이 별로 없어요. 조금 더 놀고 나서 일기를 쓸래요!", "status": "today_empty"}
        diary_context = ""
        try:
            context_items = []
            for record in todays_analysis:
                created_at_dt = datetime.datetime.fromisoformat(record['created_at']).astimezone(kst); time_str = created_at_dt.strftime("%p %I:%M"); desc = record.get('activity_description')
                desc_str = f" (그때 나는 '{desc}' 같은 걸 하고 있었다!)" if desc else ""
                context_item = f"- {time_str}쯤: 내 기분은 긍정 점수 {record['positive_score']:.2f}점, 활동 점수 {record['active_score']:.2f}점이었다.{desc_str}"
                context_items.append(context_item)
            diary_context = "\n".join(context_items)
        except Exception as e: print(f"🚨 Diary Context Creation Error: {e}")
        prompt = f'''You are an affectionate puppy writing a diary in Korean. Your goal is to write a diary that honestly reflects your feelings, helping your owner, "주인님", understand you better.

        **How to interpret my memories:**
        - `긍정 점수` is my happiness. High score (> 0.7) means I was happy/joyful. Low score (< 0.4) means I was sad, scared, uncomfortable, or grumpy.
        - `활동 점수` is my energy. High score (> 0.7) means I was active/excited. Low score (< 0.3) means I was calm, sleepy, or bored.

        Here are my memories from today ({diary_date_str}):
        {diary_context}

        Based on these memories, write a diary entry from my perspective.
        - **DO NOT** just list the data. Weave the events into a narrative, expressing my emotions based on the scores.
        - For example, if `긍정 점수` is low during a vet visit, you could write: "오늘 병원에 갔는데 주사가 너무 무서웠어... 낑... 그래도 주인님이 꼭 안아줘서 꾹 참았어."
        - Even if I had a bad moment, **always end the diary with a loving message for my "주인님"**, showing my unconditional love.
        - Write in a cute, affectionate tone, but be truthful to the emotions from the data. Use words like "멍!" or "킁킁".'''
        try:
            response = await gemini_model.generate_content_async(prompt)
            diary_content = response.text; await asyncio.to_thread(sync_save_diary, user_id, dog_id, diary_date_str, diary_content)
            return {"content": diary_content, "status": "created"}
        except Exception as e: print(f"🚨 Diary Generation/Save Error: {e}"); raise HTTPException(500, "Failed to write diary.")
    return {"content": "일기를 가져오는 데 문제가 생겼어요.", "status": "error"}

@app.post("/api/v1/chatbot/query")
async def get_chatbot_response_endpoint(request_data: dict, user: dict = Depends(get_current_user)):
    user_id = user.get('sub'); dog_id = request_data.get("dog_id"); user_query = request_data.get("query")
    if not all([user_id, dog_id, user_query]): raise HTTPException(400, "user_id, dog_id, and query are required.")
    if not gemini_model: raise HTTPException(503, "Chatbot model not available.")

    daily_keywords = ["오늘", "지금", "현재", "일간"]; weekly_keywords = ["주간", "이번주", "이번 주"]
    recent_analyses = []; rag_type = None
    normalized_query = user_query.lower()

    if any(keyword in normalized_query for keyword in daily_keywords):
        rag_type = "오늘"
        recent_analyses = await asyncio.to_thread(sync_get_rag_analysis_data, user_id, dog_id, 'daily')
    elif any(keyword in normalized_query for keyword in weekly_keywords):
        rag_type = "이번 주"
        recent_analyses = await asyncio.to_thread(sync_get_rag_analysis_data, user_id, dog_id, 'weekly')

    rag_context = ""
    if recent_analyses:
        try:
            context_items = []
            for record in recent_analyses:
                created_at_str = record.get('created_at')
                if not created_at_str: continue
                
                kst = datetime.timezone(datetime.timedelta(hours=9))
                created_at_dt = datetime.datetime.fromisoformat(created_at_str).astimezone(kst)
                
                time_str = created_at_dt.strftime("%m월 %d일 %p %I:%M")

                desc = record.get('activity_description')
                desc_str = f" (상황: {desc})" if desc else ""
                context_item = f"- {time_str}: 긍정 점수 {record.get('positive_score', 0):.2f}, 활동 점수 {record.get('active_score', 0):.2f}{desc_str}"
                context_items.append(context_item)

            rag_context = "\n".join(context_items)
        except Exception as e:
            print(f"🚨 RAG Context Creation Error: {e}")
            rag_context = ""

    if rag_context:
        prompt = f'''You are a helpful and friendly dog behavior expert. Always answer in Korean. Your main goal is to help the owner understand their dog\'s feelings based on objective data.

        **How to interpret the analysis data:**
        - `긍정 점수` reflects the dog\'s happiness. High score (> 0.7) means joy/comfort. Low score (< 0.4) means sadness, fear, or discomfort.
        - `활동 점수` reflects the dog\'s energy level. High score (> 0.7) means excitement/playfulness. Low score (< 0.3) indicates calmness, sleepiness, or boredom.

        Please use the following analysis data for the requested period ('{rag_type}') to provide a personalized and detailed answer.

        [강아지 분석 데이터 ({rag_type})]
        {rag_context}

        Based on the data and the interpretation guide, answer the user\'s query: '{user_query}'.
        - When you see a low positive score, explain what might have caused the negative feeling (e.g., "천둥 소리 때문에 조금 불안했나 봐요.").
        - When you see a low active score, explain that the dog might have been tired, calm, or uninterested (e.g., "산책이 길어져서 쉬고 싶었을 수 있어요.").
        - Speak empathetically and provide constructive advice if applicable.'''
    else:
        prompt = f'''You are a helpful and friendly dog behavior expert. Always answer in Korean.
        The user\'s query is \'{user_query}\'. Provide a general but helpful answer. Do not ask for analysis data or mention it.'''
    try:
        response = await gemini_model.generate_content_async(prompt)
        return {"user_id": user_id, "response": response.text}
    except Exception as e: 
        print(f"🚨 Vertex AI call failed with exception: {e}")
        raise HTTPException(500, f"Vertex AI call failed: {e}")

@app.get("/")
def health_check(): return {"status": "ok", "service": "Dognal API is running!"}

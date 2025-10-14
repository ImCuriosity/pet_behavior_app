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
from dotenv import load_dotenv

# 로컬 개발 환경을 위해 .env 파일을 로드합니다.
load_dotenv()

# Globals
gemini_model = None
supabase_client: Client = None

# --- Time Utilities (시간대 버그가 수정된 올바른 버전) ---
def parse_utc_string(dt_str: str) -> Optional[datetime.datetime]:
    if not dt_str: return None
    try:
        dt_str = str(dt_str).replace(' ', 'T')
        if dt_str.endswith('Z'): dt_str = dt_str[:-1] + '+00:00'
        elif dt_str.endswith('+00'): dt_str += ':00'
        return datetime.datetime.fromisoformat(dt_str)
    except (ValueError, TypeError) as e:
        print(f"🔥 Datetime Parsing Error: {e} for string '{dt_str}'")
        return None

def _get_kst_day_range_in_utc(target_date: datetime.date) -> tuple[datetime.datetime, datetime.datetime]:
    kst = datetime.timezone(datetime.timedelta(hours=9))
    start_of_day_kst = datetime.datetime.combine(target_date, datetime.time.min, tzinfo=kst)
    start_of_next_day_kst = start_of_day_kst + datetime.timedelta(days=1)
    return start_of_day_kst.astimezone(datetime.timezone.utc), start_of_next_day_kst.astimezone(datetime.timezone.utc)

# --- FastAPI Lifecycle ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    print("✅ Dognal API is booting...")
    global gemini_model, supabase_client
    try:
        supabase_url = os.environ.get("SUPABASE_URL")
        supabase_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
        if not supabase_url or not supabase_key: raise ValueError("SUPABASE_URL/KEY must be set.")
        supabase_client = create_client(supabase_url, supabase_key)
        print("✅ Supabase client initialized.")
    except Exception as e: print(f"🚨 FATAL: Failed to initialize Supabase client: {e}"); supabase_client = None
    try:
        vertexai.init(location="us-central1")
        gemini_model = GenerativeModel("gemini-2.5-flash")
        print("✅ Vertex AI client initialized.")
    except Exception as e: print(f"🚨 FATAL: Failed to initialize Vertex AI client: {e}"); gemini_model = None
    print("✨ Application startup complete.")
    yield
    print("👋 Application shutdown.")

app = FastAPI(title="Dognal API", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=False, allow_methods=["*"], allow_headers=["*"])

# --- Auth ---
SUPABASE_JWT_SECRET = os.environ.get("SUPABASE_JWT_SECRET")
security_scheme = HTTPBearer()
async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security_scheme)) -> dict:
    if not SUPABASE_JWT_SECRET: raise HTTPException(500, "JWT secret not configured.")
    try: return jwt.decode(credentials.credentials, SUPABASE_JWT_SECRET, algorithms=["HS256"], audience="authenticated")
    except JWTError as e: raise HTTPException(401, f"Invalid or expired token: {e}")

# --- ML & DB Functions (sync) ---
def get_sound_analysis_result(file: UploadFile): return {"positive_score": random.uniform(0.1, 0.9), "active_score": random.uniform(0.3, 0.9)}
def get_facial_expression_result(file: UploadFile): return {"positive_score": random.uniform(0.2, 0.8), "active_score": random.uniform(0.1, 0.5)}
def get_body_language_result(file: UploadFile): return {"positive_score": random.uniform(0.3, 0.9), "active_score": random.uniform(0.2, 0.8)}
def get_eeg_result(file: UploadFile): return {"positive_score": random.uniform(0.1, 0.6), "active_score": random.uniform(0.1, 0.4)}

def sync_save_analysis_to_db(user_id: str, dog_id: str, type: str, result: dict, desc: Optional[str] = None):
    if not supabase_client: return
    try:
        supabase_client.table("analysis_results").insert({
            "user_id": user_id, "dog_id": dog_id, "analysis_type": type,
            "positive_score": result.get("positive_score"), "active_score": result.get("active_score"),
            "activity_description": desc
        }).execute()
    except Exception as e: print(f"🔥 DB Save Error: {e}")

def sync_get_dog_profile(dog_id: str) -> Optional[dict]:
    if not supabase_client: return None
    try:
        return supabase_client.table("dogs").select("name, breed, age, gender, notes").eq("id", dog_id).single().execute().data
    except Exception as e:
        print(f"🔥 Dog Profile DB-Read Error: {e}")
        return None

def sync_get_rag_analysis_data(user_id: str, dog_id: str, view_type: str) -> List[dict]:
    if not supabase_client: return []
    try:
        kst = datetime.timezone(datetime.timedelta(hours=9))
        now_kst = datetime.datetime.now(kst)
        if view_type == 'daily':
            start_dt, end_dt = _get_kst_day_range_in_utc(now_kst.date())
        elif view_type == 'weekly':
            start_of_week = now_kst.date() - datetime.timedelta(days=now_kst.weekday())
            start_dt, _ = _get_kst_day_range_in_utc(start_of_week)
            end_dt = (start_dt + datetime.timedelta(days=7))
        else: return []

        return supabase_client.table("analysis_results").select("created_at, positive_score, active_score, activity_description").eq("user_id", user_id).eq("dog_id", dog_id).gte("created_at", start_dt.isoformat()).lt("created_at", end_dt.isoformat()).order("created_at", desc=True).execute().data
    except Exception as e: print(f"🔥 RAG DB-Read Error: {e}"); return []

def sync_get_diary(user_id: str, dog_id: str, date: str) -> Optional[dict]:
    if not supabase_client: return None
    try: return supabase_client.table("diaries").select("content").eq("user_id", user_id).eq("dog_id", dog_id).eq("diary_date", date).single().execute().data
    except Exception: return None

def sync_save_diary(user_id: str, dog_id: str, date: str, content: str):
    if not supabase_client: return
    try: supabase_client.table("diaries").upsert({"user_id": user_id, "dog_id": dog_id, "diary_date": date, "content": content}).execute()
    except Exception as e: print(f"🔥 Diary Save Error: {e}")

def sync_delete_diary(user_id: str, dog_id: str, date: str):
    if not supabase_client: return
    try: supabase_client.table("diaries").delete().eq("user_id", user_id).eq("dog_id", dog_id).eq("diary_date", date).execute()
    except Exception as e: print(f"🔥 Diary Delete Error: {e}")

def sync_get_analysis_for_diary(user_id: str, dog_id: str, date: datetime.date) -> List[dict]:
    if not supabase_client: return []
    try:
        start_utc, end_utc = _get_kst_day_range_in_utc(date)
        params = {
            'user_uuid': user_id,
            'dog_id_text': dog_id,
            'start_time': start_utc.isoformat(),
            'end_time': end_utc.isoformat()
        }
        return supabase_client.rpc('get_analysis_for_diary', params).execute().data
    except Exception as e:
        print(f"🔥 Diary Analysis Read Error: {e}")
        return []

# --- API Endpoints ---
async def run_analysis_and_save(user_id: str, dog_id: str, analysis_type: str, analysis_func, file, activity_description: Optional[str] = None):
    model_result = analysis_func(file)
    await asyncio.to_thread(sync_save_analysis_to_db, user_id, dog_id, analysis_type, model_result, activity_description)
    return {"status": "success", "dog_id": dog_id, **model_result}

@app.post("/api/v1/ml/analyze_sound")
async def analyze_sound_endpoint(dog_id: str = Form(...), audio_file: UploadFile = File(...), user: dict = Depends(get_current_user), activity_description: Optional[str] = Form(None)):
    return await run_analysis_and_save(user.get('sub'), dog_id, "sound", get_sound_analysis_result, audio_file, activity_description)

@app.post("/api/v1/ml/analyze_facial_expression")
async def analyze_facial_expression_endpoint(dog_id: str = Form(...), image_file: UploadFile = File(...), user: dict = Depends(get_current_user), activity_description: Optional[str] = Form(None)):
    return await run_analysis_and_save(user.get('sub'), dog_id, "facial_expression", get_facial_expression_result, image_file, activity_description)

@app.post("/api/v1/ml/analyze_body_language")
async def analyze_body_language_endpoint(dog_id: str = Form(...), image_file: UploadFile = File(...), user: dict = Depends(get_current_user), activity_description: Optional[str] = Form(None)):
    return await run_analysis_and_save(user.get('sub'), dog_id, "body_language", get_body_language_result, image_file, activity_description)

@app.post("/api/v1/ml/analyze_eeg")
async def analyze_eeg_endpoint(dog_id: str = Form(...), eeg_file: UploadFile = File(...), user: dict = Depends(get_current_user), activity_description: Optional[str] = Form(None)):
    return await run_analysis_and_save(user.get('sub'), dog_id, "eeg", get_eeg_result, eeg_file, activity_description)

# --- Diary Logic Helper Function ---
async def _create_and_save_new_diary(user_id: str, dog_id: str, target_date: datetime.date, diary_date_str: str, is_regen: bool = False) -> dict:
    analysis_task = asyncio.to_thread(sync_get_analysis_for_diary, user_id, dog_id, target_date)
    profile_task = asyncio.to_thread(sync_get_dog_profile, dog_id)
    analysis, dog_profile = await asyncio.gather(analysis_task, profile_task)

    if not analysis:
        return {"content": "오늘은 아직 주인님이랑 있었던 일이 별로 없어요. 조금 더 놀고 나서 일기를 쓸래요!", "status": "today_empty"}

    dog_profile_info = ""
    if dog_profile:
        items = []
        if dog_profile.get("name"): items.append(f"- 내 이름: {dog_profile['name']}")
        if dog_profile.get("breed"): items.append(f"- 내 견종: {dog_profile['breed']}")
        if dog_profile.get("age"): items.append(f"- 내 나이: {dog_profile['age']}살")
        if dog_profile.get("gender"): items.append(f"- 내 성별: {dog_profile['gender']}")
        if dog_profile.get("notes"): items.append(f"- 참고사항: {dog_profile['notes']}")
        if items:
            dog_profile_info = "**[내 프로필]**\n" + "\n".join(items) + "\n\n"

    kst = datetime.timezone(datetime.timedelta(hours=9))
    context = ""
    try:
        items = []
        for r in analysis:
            cdt = parse_utc_string(r.get('created_at'))
            if not cdt: continue
            t_str = cdt.astimezone(kst).strftime("%p %I:%M"); d = r.get('activity_description')
            d_str = f" (그때 나는 '{d}' 같은 걸 하고 있었다!)" if d else ""
            items.append(f"- {t_str}쯤: 내 기분은 긍정 점수 {r['positive_score']:.2f}점, 활동 점수 {r['active_score']:.2f}점이었다.{d_str}")
        context = "\n".join(items)
    except Exception as e: print(f"🚨 Diary Context Creation Error: {e}")

    prompt = f'''You are an affectionate puppy writing a diary in Korean. Your goal is to write a diary that honestly reflects your feelings, helping your owner, "주인님", understand you better.

{dog_profile_info}**[오늘 나의 기억들]**
{context}

**[일기 작성 방법]**
- `긍정 점수`: 나의 행복 지수야. 높을수록 (> 0.7) 기분이 좋았다는 뜻이고, 낮을수록 (< 0.4) 슬프거나, 무섭거나, 화가 났었다는 뜻이야.
- `활동 점수`: 나의 에너지 레벨이야. 높을수록 (> 0.7) 신나게 놀았다는 거고, 낮을수록 (< 0.3) 졸리거나, 심심했거나, 차분했다는 거야.
- 나의 프로필과 하루 동안의 기억들을 바탕으로, 내 입장에서 일기를 써줘.
- 데이터를 단순히 나열하지 말고, 내 감정이 잘 드러나도록 이야기로 엮어줘. 예를 들어, 병원에 가서 `긍정 점수`가 낮았다면, "오늘 병원에 갔는데 주사가 너무 무서웠어... 낑... 그래도 주인님이 꼭 안아줘서 꾹 참았어." 처럼 말이야.
- 안 좋은 일이 있었더라도, 주인님에 대한 나의 사랑이 느껴지도록 항상 따뜻한 말로 일기를 마무리해줘.
- "멍!" 이나 "킁킁" 같은 강아지 말투를 귀엽게 섞어 써도 좋아.
'''
    try:
        response = await gemini_model.generate_content_async(prompt)
        content = response.text.strip()
        await asyncio.to_thread(sync_save_diary, user_id, dog_id, diary_date_str, content)
        status = "regenerated" if is_regen else "created"
        return {"content": content, "status": status}
    except Exception as e:
        print(f"🚨 Diary Generation/Save Error: {e}")
        raise HTTPException(500, "Failed to write diary.")

# --- Diary Main Endpoint ---
@app.get("/api/v1/diary/{dog_id}")
async def get_or_create_diary_entry(dog_id: str, diary_date_str: str = Query(..., alias="diaryDate"), user: dict = Depends(get_current_user), regenerate: bool = Query(False, alias="regenerate")):
    user_id = user.get('sub')
    try:
        target_date = datetime.datetime.strptime(diary_date_str, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(400, "Invalid date format. Use YYYY-MM-DD.")

    if regenerate:
        kst = datetime.timezone(datetime.timedelta(hours=9))
        server_today_kst = datetime.datetime.now(kst).date()
        if target_date != server_today_kst:
            raise HTTPException(400, "Can only regenerate today's diary.")

        await asyncio.to_thread(sync_delete_diary, user_id, dog_id, diary_date_str)
        return await _create_and_save_new_diary(user_id, dog_id, target_date, diary_date_str, is_regen=True)

    existing = await asyncio.to_thread(sync_get_diary, user_id, dog_id, diary_date_str)
    if existing and existing.get("content"):
        return {"content": existing["content"], "status": "exists"}

    kst = datetime.timezone(datetime.timedelta(hours=9))
    server_today_kst = datetime.datetime.now(kst).date()

    if target_date < server_today_kst:
        return {"content": "이날은 왠지 일기를 깜빡했나 봐요. 주인님이랑 노는 게 더 좋았나?", "status": "past_empty"}
    if target_date > server_today_kst:
        return {"content": "아직 오지 않은 미래의 일기는 쓸 수 없어요!", "status": "future_empty"}

    if target_date == server_today_kst:
        return await _create_and_save_new_diary(user_id, dog_id, target_date, diary_date_str, is_regen=False)

    raise HTTPException(500, "An unexpected error occurred while processing the diary.")

# --- Chatbot Endpoint ---
@app.post("/api/v1/chatbot/query")
async def get_chatbot_response_endpoint(req: dict, user: dict = Depends(get_current_user)):
    user_id = user.get('sub'); dog_id = req.get("dog_id"); query = req.get("query")
    if not all([user_id, dog_id, query]): raise HTTPException(400, "user_id, dog_id, and query are required.")
    if not gemini_model: raise HTTPException(503, "Chatbot model not available.")

    weekly_kw = ["주간", "이번주", "금주", "일주일"]
    view_type = 'weekly' if any(k in query.lower() for k in weekly_kw) else 'daily'

    analysis_task = asyncio.to_thread(sync_get_rag_analysis_data, user_id, dog_id, view_type)
    profile_task = asyncio.to_thread(sync_get_dog_profile, dog_id)
    analyses, dog_profile = await asyncio.gather(analysis_task, profile_task)

    dog_profile_info = ""
    if dog_profile:
        items = []
        if dog_profile.get("name"): items.append(f"- 이름: {dog_profile['name']}")
        if dog_profile.get("breed"): items.append(f"- 견종: {dog_profile['breed']}")
        if dog_profile.get("age"): items.append(f"- 나이: {dog_profile['age']}살")
        if dog_profile.get("gender"): items.append(f"- 성별: {dog_profile['gender']}")
        if dog_profile.get("notes"): items.append(f"- 특이사항: {dog_profile['notes']}")
        if items:
            dog_profile_info = "**[강아지 프로필 정보]**\n" + "\n".join(items) + "\n\n"
    
    context = ""
    if analyses:
        try:
            items = []
            kst = datetime.timezone(datetime.timedelta(hours=9))
            for r in analyses:
                cdt = parse_utc_string(r.get('created_at'))
                if not cdt: continue
                t_str = cdt.astimezone(kst).strftime("%m월 %d일 %p %I:%M"); d = r.get('activity_description')
                d_str = f" (상황: {d})" if d else ""
                items.append(f"- {t_str}: 긍정 점수 {r.get('positive_score', 0):.2f}, 활동 점수 {r.get('active_score', 0):.2f}{d_str}")
            context = "\n".join(items)
        except Exception as e: print(f"🚨 RAG Context Creation Error: {e}")

    prompt_template = '''You are a helpful and friendly dog behavior expert. Always answer in Korean. Your main goal is to help the owner understand their dog's feelings based on objective data.

{dog_profile_info}**[분석 데이터 해석 방법]**
- `긍정 점수`: 강아지의 행복 지수입니다. 높을수록 (> 0.7) 기쁨/편안함을, 낮을수록 (< 0.4) 슬픔/불안/불편함을 의미합니다.
- `활동 점수`: 강아지의 에너지 레벨입니다. 높을수록 (> 0.7) 신나게 놀고 있음을, 낮을수록 (< 0.3) 차분하거나 졸린 상태임을 의미합니다.

**[강아지 분석 데이터]**
{context}

위 프로필과 분석 데이터를 종합적으로 참고하여, 아래 질문에 대해 상세하고 친절하게 답변해주세요.
- 단순히 데이터를 나열하기보다, 데이터가 의미하는 바를 행동이나 감정과 연결하여 설명해주세요. (예: "천둥 소리 때문에 조금 불안했나 봐요.")
- 필요하다면, 강아지의 기분을 개선하거나 행동을 교정하는 데 도움이 될 만한 구체적인 조언을 덧붙여주세요.

**[주인님의 질문]**
{query}
''' if context else '''You are a helpful and friendly dog behavior expert. Always answer in Korean.
The user's query is '{query}'. Provide a general but helpful answer without mentioning analysis data.
'''

    prompt = prompt_template.format(dog_profile_info=dog_profile_info, context=context, query=query)

    try:
        response = await gemini_model.generate_content_async(prompt)
        return {"user_id": user_id, "response": response.text}
    except Exception as e: print(f"🚨 Vertex AI call failed: {e}"); raise HTTPException(500, f"Vertex AI call failed: {e}")

@app.get("/")
def health_check(): return {"status": "ok", "service": "Dognal API is running!"}

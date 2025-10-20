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
import httpx

# 로컬 개발 환경을 위해 .env 파일을 로드합니다.
load_dotenv()

# Globals
gemini_model = None
supabase_client: Client = None

# --- [수정] Cloud Run 서비스 URL 환경 변수를 추가합니다. ---
EEG_ANALYZER_URL = os.environ.get("EEG_ANALYZER_URL")
FACIAL_ANALYZER_URL = os.environ.get("FACIAL_ANALYZER_URL")
SOUND_ANALYZER_URL = os.environ.get("SOUND_ANALYZER_URL")


# --- Time Utilities (변경 없음) ---
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
    end_of_day_kst = datetime.datetime.combine(target_date, datetime.time.max, tzinfo=kst)
    return start_of_day_kst.astimezone(datetime.timezone.utc), end_of_day_kst.astimezone(datetime.timezone.utc)

# --- FastAPI Lifecycle (변경 없음) ---
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

# --- Auth (변경 없음) ---
SUPABASE_JWT_SECRET = os.environ.get("SUPABASE_JWT_SECRET")
security_scheme = HTTPBearer()
async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security_scheme)) -> dict:
    if not SUPABASE_JWT_SECRET: raise HTTPException(500, "JWT secret not configured.")
    try: return jwt.decode(credentials.credentials, SUPABASE_JWT_SECRET, algorithms=["HS256"], audience="authenticated")
    except JWTError as e: raise HTTPException(401, f"Invalid or expired token: {e}")

# --- ML & DB Functions ---

# 임시 함수 (몸짓)
def get_body_language_result(file: UploadFile): return {"positive_score": random.uniform(0.3, 0.9), "active_score": random.uniform(0.2, 0.8)}

# 마이크로서비스 호출 함수들
async def get_eeg_result_from_cloud_run(eeg_file: UploadFile) -> dict:
    # (내용 변경 없음)
    if not EEG_ANALYZER_URL:
        raise HTTPException(status_code=503, detail="EEG 분석 서비스가 설정되지 않았습니다.")
    if not eeg_file.filename.endswith(('.xlsx', '.xls')):
        raise HTTPException(status_code=400, detail="EEG 분석은 Excel 파일(.xlsx, .xls)만 가능합니다.")
    file_content = await eeg_file.read()
    async with httpx.AsyncClient(timeout=60.0) as client:
        try:
            files = {'file': (eeg_file.filename, file_content, eeg_file.content_type)}
            response = await client.post(f"{EEG_ANALYZER_URL}/analyze/", files=files)
            response.raise_for_status()
            result_data = response.json()
            return {
                "positive_score": result_data.get("positive_percent", 0) / 100.0,
                "active_score": result_data.get("active_percent", 0) / 100.0
            }
        except httpx.RequestError as exc:
            raise HTTPException(status_code=503, detail=f"EEG 분석 서비스 연결에 실패했습니다: {exc}")
        except httpx.HTTPStatusError as exc:
            raise HTTPException(status_code=exc.response.status_code, detail=f"EEG 분석 서비스 오류: {exc.response.text}")

async def get_facial_result_from_cloud_run(video_file: UploadFile) -> dict:
    # (내용 변경 없음)
    if not FACIAL_ANALYZER_URL:
        raise HTTPException(status_code=503, detail="표정 분석 서비스가 설정되지 않았습니다.")
    if not video_file.content_type.startswith("video/"):
        raise HTTPException(status_code=400, detail="표정 분석은 비디오 파일만 가능합니다.")
    file_content = await video_file.read()
    async with httpx.AsyncClient(timeout=120.0) as client:
        try:
            files = {'video_file': (video_file.filename, file_content, video_file.content_type)}
            response = await client.post(f"{FACIAL_ANALYZER_URL}/predict", files=files)
            response.raise_for_status()
            return response.json()
        except httpx.RequestError as exc:
            raise HTTPException(status_code=503, detail=f"표정 분석 서비스 연결에 실패했습니다: {exc}")
        except httpx.HTTPStatusError as exc:
            raise HTTPException(status_code=exc.response.status_code, detail=f"표정 분석 서비스 오류: {exc.response.text}")

# ▼▼▼ [추가] 소리 분석 마이크로서비스를 호출하는 함수를 추가합니다. ▼▼▼
async def get_sound_result_from_cloud_run(audio_file: UploadFile) -> dict:
    """Cloud Run에 배포된 소리 분석 서비스를 호출합니다."""
    if not SOUND_ANALYZER_URL:
        raise HTTPException(status_code=503, detail="소리 분석 서비스가 설정되지 않았습니다.")

    # FFmpeg가 다양한 오디오 형식을 처리하므로, content_type으로만 검사합니다.
    if not audio_file.content_type.startswith("audio/"):
        raise HTTPException(status_code=400, detail="소리 분석은 오디오 파일만 가능합니다.")

    file_content = await audio_file.read()

    async with httpx.AsyncClient(timeout=60.0) as client:
        try:
            # 소리 분석 서비스는 'audio_file'이라는 이름의 파라미터를 기대합니다.
            files = {'audio_file': (audio_file.filename, file_content, audio_file.content_type)}

            response = await client.post(f"{SOUND_ANALYZER_URL}/predict", files=files)
            response.raise_for_status()

            # 소리 분석 서비스는 이미 0~1 사이의 점수를 반환하므로 변환이 필요 없습니다.
            return response.json()

        except httpx.RequestError as exc:
            raise HTTPException(status_code=503, detail=f"소리 분석 서비스 연결에 실패했습니다: {exc}")
        except httpx.HTTPStatusError as exc:
            raise HTTPException(status_code=exc.response.status_code, detail=f"소리 분석 서비스 오류: {exc.response.text}")

# --- ▼▼▼ [복구] 누락된 다이어리/챗봇 DB 함수들 ▼▼▼ ---
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

def sync_get_rag_data(user_id: str, dog_id: str, view_type: str) -> List[dict]:
    if not supabase_client: return []
    try:
        params = { 'p_user_uuid': user_id, 'p_dog_id_text': dog_id, 'p_view_type': view_type }
        return supabase_client.rpc('get_rag_data', params).execute().data
    except Exception as e:
        print(f"🔥 RAG DB-Read Error: {e}")
        return []

def sync_get_analysis_for_diary(user_id: str, dog_id: str, target_date: datetime.date) -> List[dict]:
    if not supabase_client: return []
    try:
        start_utc, end_utc = _get_kst_day_range_in_utc(target_date)
        params = {
            'p_user_uuid': user_id,
            'p_dog_id_text': dog_id,
            'p_start_time': start_utc.isoformat(),
            'p_end_time': end_utc.isoformat()
        }
        return supabase_client.rpc('get_analysis_for_diary', params).execute().data
    except Exception as e:
        print(f"🔥 Diary Analysis Read Error: {e}")
        return []

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

# --- API Endpoints ---
async def run_analysis_and_save(user_id: str, dog_id: str, analysis_type: str, analysis_func, file, activity_description: Optional[str] = None):
    model_result = analysis_func(file)
    await asyncio.to_thread(sync_save_analysis_to_db, user_id, dog_id, analysis_type, model_result, activity_description)
    return {"status": "success", "dog_id": dog_id, **model_result}

@app.post("/api/v1/ml/analyze_body_language")
async def analyze_body_language_endpoint(dog_id: str = Form(...), image_file: UploadFile = File(...), user: dict = Depends(get_current_user), activity_description: Optional[str] = Form(None)):
    return await run_analysis_and_save(user.get('sub'), dog_id, "body_language", get_body_language_result, image_file, activity_description)

# ▼▼▼ [수정] 소리 분석 엔드포인트를 수정합니다. ▼▼▼
@app.post("/api/v1/ml/analyze_sound")
async def analyze_sound_endpoint(
        dog_id: str = Form(...),
        audio_file: UploadFile = File(...),
        user: dict = Depends(get_current_user),
        activity_description: Optional[str] = Form(None)
):
    model_result = await get_sound_result_from_cloud_run(audio_file)
    user_id = user.get('sub')
    await asyncio.to_thread(sync_save_analysis_to_db, user_id, dog_id, "sound", model_result, activity_description)
    return {"status": "success", "dog_id": dog_id, **model_result}

@app.post("/api/v1/ml/analyze_facial_expression")
async def analyze_facial_expression_endpoint(
        dog_id: str = Form(...),
        video_file: UploadFile = File(..., alias="image_file"),
        user: dict = Depends(get_current_user),
        activity_description: Optional[str] = Form(None)
):
    model_result = await get_facial_result_from_cloud_run(video_file)
    user_id = user.get('sub')
    await asyncio.to_thread(sync_save_analysis_to_db, user_id, dog_id, "facial_expression", model_result, activity_description)
    return {"status": "success", "dog_id": dog_id, **model_result}

@app.post("/api/v1/ml/analyze_eeg")
async def analyze_eeg_endpoint(dog_id: str = Form(...), eeg_file: UploadFile = File(...), user: dict = Depends(get_current_user), activity_description: Optional[str] = Form(None)):
    model_result = await get_eeg_result_from_cloud_run(eeg_file)
    user_id = user.get('sub')
    await asyncio.to_thread(sync_save_analysis_to_db, user_id, dog_id, "eeg", model_result, activity_description)
    return {"status": "success", "dog_id": dog_id, **model_result}

# --- ▼▼▼ [복구] 누락된 다이어리/챗봇 API 엔드포인트 ▼▼▼ ---
async def _create_and_save_new_diary(user_id: str, dog_id: str, target_date: datetime.date, diary_date_str: str, is_regen: bool = False) -> dict:
    analysis_task = asyncio.to_thread(sync_get_analysis_for_diary, user_id, dog_id, target_date)
    profile_task = asyncio.to_thread(sync_get_dog_profile, dog_id)
    analysis, dog_profile = await asyncio.gather(analysis_task, profile_task)

    if not analysis:
        return {"content": "오늘은 아직 주인님이랑 있었던 일이 별로 없어요. 조금 더 놀고 나서 일기를 쓸래요!", "status": "today_empty"}

    dog_profile_info = ""
    if dog_profile:
        items = [f"- 내 이름: {dog_profile.get('name', '미정')}"]
        if dog_profile.get("breed"): items.append(f"- 내 견종: {dog_profile['breed']}")
        if dog_profile.get("age"): items.append(f"- 내 나이: {dog_profile['age']}살")
        dog_profile_info = "**[내 프로필]**\n" + "\n".join(items) + "\n\n"

    kst = datetime.timezone(datetime.timedelta(hours=9))
    context = ""
    try:
        items = []
        for r in analysis:
            cdt = parse_utc_string(r.get('created_at'))
            if not cdt: continue
            t_str = cdt.astimezone(kst).strftime("%p %I:%M")
            d = r.get('activity_description')
            d_str = f" (그때 나는 '{d}' 같은 걸 하고 있었다!)" if d else ""
            items.append(f"- {t_str}쯤: 내 기분은 긍정 점수 {r['positive_score']:.2f}점, 활동 점수 {r['active_score']:.2f}점이었다.{d_str}")
        context = "**[오늘 나의 기억들]**\n" + "\n".join(items)
    except Exception as e: print(f"🚨 Diary Context Creation Error: {e}")

    prompt = f'''You are an affectionate puppy writing a diary in Korean. Your goal is to write a diary that honestly reflects your feelings, helping your owner, "주인님", understand you better.

{dog_profile_info}**[오늘 나의 기억들]**
{context}

**[일기 작성 방법]**
- `긍정 점수`: 나의 행복 지수야. 높을수록 (> 0.7) 기분이 좋았다는 뜻이고, 낮을수록 (< 0.4) 슬프거나, 무섭거나, 화가 났었다는 뜻이야.
- `활동 점수`: 나의 에너지 레벨이야. 높을수록 (> 0.7) 신나게 놀았다는 거고, 낮을수록 (< 0.3) 졸리거나, 심심했거나, 차분했다는 거야.
- 나의 프로필과 하루 동안의 기억들을 바탕으로, 내 입장에서 일기를 써줘.
- 데이터를 단순히 나열하지 말고, 내 감정이 잘 드러나도록 이야기로 엮어줘. 예를 들어, 병원에 가서 `긍정 점수`가 낮았다면, "오늘 병원에 갔는데 주사가 너무 무서웠어... 낑... 그래도 주인님이 꼭 안아줘서 꾹 참았어." 처럼 말이야.
- **절대로 일기 본문에 날짜를 쓰지 마.** 날짜는 이미 앱 화면에 표시되고 있어.
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

    return await _create_and_save_new_diary(user_id, dog_id, target_date, diary_date_str)

@app.post("/api/v1/chatbot/query")
async def get_chatbot_response_endpoint(req: dict, user: dict = Depends(get_current_user)):
    user_id = user.get('sub')
    dog_id = req.get("dog_id")
    query = req.get("query")
    if not all([dog_id, query]): raise HTTPException(400, "dog_id and query are required.")
    if not gemini_model: raise HTTPException(503, "Chatbot model not available.")

    # 1. RAG 데이터 조회를 위한 키워드 정의
    DAILY_KEYWORDS = ["오늘", "지금", "기분", "상태", "컨디션", "요즘"]
    WEEKLY_KEYWORDS = ["주간", "이번 주", "이 주", "이번주", "weekly"]

    # 2. 변수 초기화
    analyses = None
    view_type = None

    # 3. 사용자 질문을 소문자로 변환하여 키워드 매칭 준비
    query_lower = query.lower()

    if any(k in query_lower for k in DAILY_KEYWORDS):
        view_type = 'daily'
    elif any(k in query_lower for k in WEEKLY_KEYWORDS):
        view_type = 'weekly'

    # 4. view_type이 결정되었을 때만 RAG 데이터와 프로필을 함께 조회
    if view_type:
        # RAG 데이터와 프로필을 함께 조회
        analysis_task = asyncio.to_thread(sync_get_rag_data, user_id, dog_id, view_type)
        profile_task = asyncio.to_thread(sync_get_dog_profile, dog_id)
        analyses, dog_profile = await asyncio.gather(analysis_task, profile_task)
    else:
        # RAG 키워드가 없으면 프로필만 조회
        analyses = []
        dog_profile = await asyncio.to_thread(sync_get_dog_profile, dog_id)

    dog_profile_info = ""
    if dog_profile:
        items = [f"- 이름: {dog_profile.get('name', '미정')}"]
        if dog_profile.get("breed"): items.append(f"- 견종: {dog_profile['breed']}")
        dog_profile_info = "**[강아지 프로필 정보]**\n" + "\n".join(items) + "\n\n"

    context = ""
    if analyses:
        try:
            kst = datetime.timezone(datetime.timedelta(hours=9))
            items = []
            for r in analyses:
                created_dt = parse_utc_string(r.get('created_at'))
                if not created_dt: continue

                time_format = "%p %I:%M" if view_type == 'daily' else "%m월 %d일 %p %I:%M"
                time_str = created_dt.astimezone(kst).strftime(time_format)

                description = r.get('activity_description')
                desc_str = f", 활동 내용: {description}" if description else ""

                positive_score = r.get('positive_score', 0)
                active_score = r.get('active_score', 0)

                items.append(
                    f"- {time_str} 경: 긍정 점수 {positive_score:.2f}, 활동 점수 {active_score:.2f}{desc_str}"
                )

            if items:
                context = "**[강아지 분석 데이터]**\n" + "\n".join(items)
        except Exception as e:
            print(f"🚨 RAG Context Creation Error: {e}")

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
''' if context else '''You are a helpful and friendly dog behavior expert. Always answer in Korean. Your main goal is to help the owner understand their dog's feelings.

{dog_profile_info}
위 강아지 프로필을 참고해서 아래 질문에 답변해주세요. 데이터 분석 결과는 따로 없으니, 일반적인 강아지 행동 전문가 입장에서 조언해주시면 됩니다.

**[주인님의 질문]**
{query}
'''
    prompt = prompt_template.format(dog_profile_info=dog_profile_info, context=context, query=query)
    try:
        response = await gemini_model.generate_content_async(prompt)
        # --- [수정] Flutter 앱이 기대하는 정확한 JSON 형식으로 반환합니다. ---
        return {"response": response.text}
    except Exception as e:
        print(f"🚨 Vertex AI call failed: {e}")
        raise HTTPException(500, f"Vertex AI call failed: {e}")

@app.get("/")
def health_check():
    return {"status": "ok", "service": "Dognal API is running!"}


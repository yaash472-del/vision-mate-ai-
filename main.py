import os
import base64
import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

load_dotenv()
app = FastAPI(title="VisionMate AI API", version="0.1.0")

# Development setting. Restrict allowed origins before production.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

API_KEY = os.getenv("GEMINI_API_KEY", "")
MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
MAX_BYTES = 8 * 1024 * 1024
ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp"}


@app.get("/")
def root():
    return {"app": "VisionMate AI", "status": "running"}


@app.get("/health")
def health():
    return {"status": "ok", "gemini_configured": bool(API_KEY)}


async def validate_image(image: UploadFile):
    content_type = image.content_type or ""
    if content_type not in ALLOWED_TYPES:
        raise HTTPException(415, "Upload a JPG, PNG or WEBP image.")
    raw = await image.read()
    if not raw:
        raise HTTPException(400, "The image is empty.")
    if len(raw) > MAX_BYTES:
        raise HTTPException(413, "Image must be smaller than 8 MB.")
    return raw, content_type


async def gemini_image_request(raw: bytes, content_type: str, prompt: str):
    if not API_KEY or API_KEY.startswith("PASTE_"):
        raise HTTPException(503, "Gemini key missing. Add GEMINI_API_KEY to backend/.env.")

    encoded = base64.b64encode(raw).decode("utf-8")
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"
    payload = {
        "contents": [{
            "parts": [
                {"text": prompt},
                {"inline_data": {"mime_type": content_type, "data": encoded}}
            ]
        }],
        "generationConfig": {"temperature": 0.2, "maxOutputTokens": 250}
    }
    try:
        async with httpx.AsyncClient(timeout=40) as client:
            response = await client.post(
                url, params={"key": API_KEY}, json=payload
            )
        if response.is_error:
            raise HTTPException(502, f"Gemini API returned {response.status_code}. Check model, key and quota.")
        data = response.json()
        return data["candidates"][0]["content"]["parts"][0]["text"].strip()
    except HTTPException:
        raise
    except (httpx.HTTPError, KeyError, IndexError, TypeError):
        raise HTTPException(502, "Could not get a valid response from the AI service.")


@app.post("/api/vision/describe")
async def describe_scene(image: UploadFile = File(...)):
    raw, mime = await validate_image(image)
    prompt = (
        "Describe this image for a blind or low-vision user in simple concise language. "
        "Mention visible objects and approximate left/centre/right positions only if clear. "
        "State uncertainty. Never say a road is safe to cross and never give crossing instructions."
    )
    result = await gemini_image_request(raw, mime, prompt)
    return {
        "description": result,
        "notice": "AI descriptions can be wrong. Do not use this response to decide when to cross a road."
    }


@app.post("/api/vision/read-text")
async def read_text(image: UploadFile = File(...)):
    raw, mime = await validate_image(image)
    prompt = (
        "Transcribe only text clearly visible in this image. Preserve numbers and units. "
        "If text is blurry or uncertain, say so. Do not guess medicine instructions or dosage."
    )
    result = await gemini_image_request(raw, mime, prompt)
    return {
        "text": result,
        "notice": "Check important labels with a trusted person; transcription may contain errors."
    }


@app.post("/api/vision/bus")
async def identify_bus(image: UploadFile = File(...)):
    raw, mime = await validate_image(image)
    prompt = (
        "Look for a bus and clearly readable route number or destination text. "
        "Report only legible text. Do not claim it is the correct bus to board."
    )
    result = await gemini_image_request(raw, mime, prompt)
    return {
        "result": result,
        "notice": "Confirm the bus route with the driver or transport staff before boarding."
    }


@app.post("/api/vision/ask")
async def ask_about_image(
    image: UploadFile = File(...),
    question: str = Form(...)
):
    question = question.strip()
    if not question or len(question) > 300:
        raise HTTPException(400, "Question must be 1–300 characters.")
    raw, mime = await validate_image(image)
    prompt = (
        "Answer this visual question for a blind or low-vision user in one or two short sentences: "
        f"{question}. Describe only visible evidence. Say when uncertain. Never decide whether "
        "it is safe to cross a road."
    )
    result = await gemini_image_request(raw, mime, prompt)
    return {"answer": result}

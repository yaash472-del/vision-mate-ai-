# VisionMate AI — Flutter frontend + FastAPI backend

This is a runnable starter prototype for an Android accessibility app.

## Included
- Flutter dashboard with all seven feature screens
- Camera image capture for Live Assistant, Read Text, Bus Assistant and Find Objects
- Gemini image-description backend endpoint
- GPS coordinate reader
- Voice output and basic voice commands
- Emergency SMS composer that opens the SMS app for the user to review/send
- Road Assist safety notice (not a road-crossing decision system)

## Safety
This prototype is NOT a certified mobility aid. It cannot reliably detect every vehicle, hidden hazard, road edge or traffic signal. It must never tell a user that it is safe to cross. Do not use it to cross live roads. Road safety requires dedicated on-device models, sensor validation, expert mobility input and extensive supervised testing.

## Requirements
- Flutter stable SDK and Android Studio
- Python 3.10+
- Gemini API key from https://aistudio.google.com/

## Backend setup (Windows)
```powershell
cd backend
py -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
```
Edit `.env` and set `GEMINI_API_KEY=your_key`, then:
```powershell
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
Check http://127.0.0.1:8000/health

## Flutter setup
From the project root:
```powershell
cd mobile_app
flutter create . --platforms android
flutter pub get
```
The supplied `lib/main.dart` and `pubspec.yaml` are the app code/dependencies.

### Android permissions
Edit `mobile_app/android/app/src/main/AndroidManifest.xml`. Add these above `<application>`:
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.INTERNET"/>
```
For local HTTP development only, add `android:usesCleartextTraffic="true"` to the `<application ...>` tag. For production, use HTTPS and remove cleartext traffic.

### Backend URL
`mobile_app/lib/main.dart` uses `http://10.0.2.2:8000` for the Android emulator.
For a physical Android phone, replace it with your laptop's local Wi-Fi IP, e.g. `http://192.168.1.20:8000`. Both devices must be on the same Wi-Fi.

## Run
Keep the backend running, then:
```powershell
cd mobile_app
flutter run
```

## API endpoints
- `GET /health`
- `POST /api/vision/describe` (multipart field: `image`)
- `POST /api/vision/read-text` (multipart field: `image`)
- `POST /api/vision/bus` (multipart field: `image`)
- `POST /api/vision/ask` (multipart fields: `image`, `question`)

## Current prototype limitations
- Navigation reads GPS coordinates; turn-by-turn routing is not implemented.
- Road Assist is intentionally a safety notice only, not vehicle detection.
- Text reading uses Gemini visual transcription as a demo; production should use on-device OCR and verify critical text.
- Bus route recognition is experimental and must be confirmed with transport staff.
- Emergency SMS is prepared in the phone's messaging app; it is not silently sent.
- Keep API keys out of Flutter code and GitHub.

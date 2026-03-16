# 🌐 AI Voice Translator — v2.0 (Node.js + Flutter)

Real-time language translation during 1-to-1 phone calls. Converted from Python/Flask to Node.js + redesigned from room-based to direct contact calling.

---

## 📁 Project Structure

```
ai_voice_translator/
├── backend/                   ← Node.js Express + Socket.IO server
│   ├── src/
│   │   ├── server.js          ← Entry point
│   │   ├── models/index.js    ← Mongoose schemas (CallLog, Message, User)
│   │   ├── services/
│   │   │   ├── socketService.js    ← 1-to-1 call signaling + translation pipeline
│   │   │   ├── whisperService.js   ← OpenAI Whisper STT
│   │   │   ├── translationService.js ← LibreTranslate + OpenRouter fallback
│   │   │   └── ttsService.js       ← OpenAI TTS / ElevenLabs
│   │   └── routes/
│   │       ├── calls.js       ← Call CRUD REST API
│   │       ├── translation.js ← /api/translation/translate
│   │       ├── speech.js      ← /api/speech/transcribe
│   │       ├── tts.js         ← /api/tts/synthesize
│   │       ├── messages.js    ← Transcript storage
│   │       └── users.js       ← User registration/lookup
│   ├── .env                   ← Environment variables
│   └── package.json
│
└── flutter_app/               ← Flutter frontend
    └── lib/
        ├── main.dart           ← App entry + routing + AppState
        ├── screens/
        │   ├── login_screen.dart         ← User login / registration
        │   ├── contacts_screen.dart      ← Device contacts + call initiation
        │   ├── incoming_call_screen.dart ← Accept/reject incoming calls
        │   ├── call_screen.dart          ← Active call + live subtitles
        │   ├── language_screen.dart      ← Language settings
        │   └── history_screen.dart       ← Call history + transcript viewer
        ├── services/
        │   ├── socket_service.dart ← Socket.IO client (Node.js compatible)
        │   ├── api_service.dart    ← REST API client
        │   └── audio_service.dart  ← Recording + playback
        └── models/
            └── contact_model.dart  ← ContactModel, SubtitleEntry
```

---

## 🚀 Backend Setup (Node.js)

### Prerequisites
- Node.js 18+
- MongoDB Atlas account (already configured in .env)
- OpenAI API key (for Whisper STT + TTS)

### Install & Run

```bash
cd backend
npm install
npm run dev      # Development with nodemon
npm start        # Production
```

Server starts on: `http://localhost:5000`
- Health check: `http://localhost:5000/health`
- Admin panel:   `http://localhost:5000/admin`

### Environment Variables (`.env`)
```
MONGO_URI=mongodb+srv://...         # Your MongoDB Atlas URI
OPENROUTER_API_KEY=sk-or-v1-...     # For LLM translation fallback
OPENAI_API_KEY=sk-...               # For Whisper STT + OpenAI TTS
LIBRETRANSLATE_URL=https://...      # Primary translation service
TTS_PROVIDER=openai                 # "openai" | "elevenlabs"
PORT=5000
```

---

## 📱 Flutter Setup

### Prerequisites
- Flutter SDK 3.x
- Android Studio / Xcode

### Install & Run

```bash
cd flutter_app
flutter pub get
flutter run
```

### Update Server URL

In `lib/services/socket_service.dart` and `lib/services/api_service.dart`:
```dart
// Android Emulator:
static const String serverUrl = 'http://10.0.2.2:5000';

// Real Device (same WiFi):
static const String serverUrl = 'http://192.168.x.x:5000';

// Production:
static const String serverUrl = 'https://your-domain.com';
```

---

## 🔄 How It Works

### Call Flow
```
User selects contact → Tap call button
       ↓
[Flutter] socket.emit('initiate_call', { callId, callerId, receiverId, ... })
       ↓
[Node.js] Looks up receiver's socketId → emit('incoming_call') to receiver
       ↓
[Receiver Flutter] Shows IncomingCallScreen → Accept/Reject
       ↓
[Node.js] emit('call_accepted') to caller
       ↓
Both enter CallScreen → WebRTC audio + translation pipeline starts
```

### Translation Pipeline (per audio chunk)
```
Microphone (Flutter) → 3-second WAV chunk
       ↓
socket.emit('audio_chunk', { audioBase64, sourceLang, targetLang })
       ↓
[Node.js] Whisper STT → original text
       ↓
[Node.js] LibreTranslate / OpenRouter → translated text
       ↓
[Node.js] OpenAI TTS → translated audio (base64 MP3)
       ↓
socket.emit('translated_audio') → other party
socket.emit('own_transcript')   → speaker
socket.emit('subtitle_update')  → both parties
       ↓
[Flutter] Display subtitle bubble + play translated audio
```

---

## 🗄️ Database Schema

### CallLog
```json
{
  "callId": "uuid-v4",
  "callerId": "phone_number",
  "receiverId": "phone_number",
  "callerName": "Alice",
  "receiverName": "Bob",
  "callerLang": "en",
  "receiverLang": "ta",
  "status": "ended",
  "startTime": "ISO date",
  "endTime": "ISO date",
  "duration": 120
}
```

### Message (Transcript)
```json
{
  "callId": "uuid-v4",
  "speaker": "phone_number",
  "speakerName": "Alice",
  "originalText": "Hello, how are you?",
  "translatedText": "நீங்கள் எப்படி இருக்கிறீர்கள்?",
  "sourceLang": "en",
  "targetLang": "ta",
  "timestamp": "ISO date",
  "type": "audio"
}
```

---

## 📦 Key Flutter Packages

| Package | Purpose |
|---|---|
| `flutter_contacts` | Read device phone contacts |
| `permission_handler` | Contacts + microphone permissions |
| `socket_io_client` | WebSocket to Node.js server |
| `flutter_sound` | Audio recording (WAV chunks) |
| `audioplayers` | Play TTS audio from server |
| `flutter_tts` | On-device TTS fallback |
| `flutter_webrtc` | WebRTC peer-to-peer audio |
| `provider` | State management |
| `shared_preferences` | Local user session storage |
| `uuid` | Generate call IDs |

---

## 🔌 Socket.IO Events Reference

### Client → Server
| Event | Payload | Description |
|---|---|---|
| `register_user` | `{userId, name, language}` | Register online presence |
| `initiate_call` | `{callId, callerId, receiverId, ...}` | Start a call |
| `answer_call` | `{callId, receiverId, accepted}` | Accept or reject |
| `end_call` | `{callId, userId}` | Hang up |
| `audio_chunk` | `{callId, userId, audioBase64, ...}` | Send audio for translation |
| `text_message` | `{callId, userId, text, ...}` | Send text for translation |
| `webrtc_offer/answer/ice` | `{callId, sdp/candidate}` | WebRTC signaling |

### Server → Client
| Event | Payload | Description |
|---|---|---|
| `incoming_call` | `{callId, callerId, callerName, callerLang}` | Notify receiver |
| `call_accepted` | `{callId}` | Receiver accepted |
| `call_rejected` | `{callId}` | Receiver rejected |
| `call_ended` | `{callId, endedBy, duration}` | Call finished |
| `translated_audio` | `{originalText, translatedText, audioBase64, ...}` | Translation result |
| `own_transcript` | `{originalText, detectedLang}` | Your own speech transcript |
| `subtitle_update` | `{senderId, originalText, translatedText, ...}` | Live subtitle update |

---

## 🌍 Supported Languages
English · Tamil · Hindi · Spanish · French · German · Japanese · Chinese · Arabic · Korean · Portuguese · Russian · Italian · Turkish · Dutch

---

## 🏗️ Architecture

```
Flutter App
    │
    ├── Socket.IO ─────────────────→ Node.js Server
    │   (real-time call signaling,       │
    │    audio chunks, subtitles)         ├── Whisper (OpenAI) ← STT
    │                                     ├── LibreTranslate   ← Translation
    └── HTTP REST ─────────────────→     ├── OpenAI TTS       ← Speech synthesis
        (call history, transcripts,       └── MongoDB Atlas    ← Storage
         user registration)
```

---

## 🚢 Deployment

### Backend (Render / Railway / Heroku)
1. Push to GitHub
2. Connect to Render → New Web Service
3. Build command: `npm install`
4. Start command: `npm start`
5. Add all .env variables in dashboard

### Flutter (Android APK)
```bash
flutter build apk --release
```

---

## ⚠️ Important Notes

1. **Contacts permission**: Required on Android; user will see a permission dialog on first launch
2. **Microphone permission**: Required for audio recording
3. **Same WiFi testing**: When testing on real devices, both must be on same network or use a deployed backend
4. **Whisper STT**: Requires `OPENAI_API_KEY` — works with standard OpenAI key
5. **TTS fallback**: If server TTS fails, Flutter uses device `flutter_tts` automatically
#   p r o j e c t  
 #   p r o j e c t  
 #   p r o j e c t  
 
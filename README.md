<div align="center">
  <h1>🛡️ SafePulse</h1>
  <p><i>Your AI-powered travel safety companion.</i></p>
  
  <img src="docs/images/home.png" width="400" alt="SafePulse Home Screen">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="docs/images/map.png" width="400" alt="SafePulse Map Screen">
</div>

---

## 🌟 What It Does

SafePulse is an advanced personal safety system designed for real-time journey monitoring, route risk scoring, crash detection, and automated emergency response coordination.

- **Real-Time Monitoring:** Tracks journey speed, phone-use risk, route risk, and emergency status.
- **Smart Routing:** Scores safe-vs-short route options using OSRM/OpenStreetMap and incident-backed risk zones.
- **AI Crash Detection:** Analyzes accelerometer/gyroscope windows through a Python AI accident-analysis service.
- **Hybrid SOS System:** Streams real-time tracking and SOS alerts through WebSockets online, with robust offline SMS fallback.
- **Safety Circles:** Maintains groups for trusted contacts and nearby responders.
- **Persistence:** Persists emergency events in a Spring Boot microservice.

---

## ⚠️ Important Note For Cloners

**If you are cloning this repository to run it yourself or build upon it, you MUST replace several placeholders and confidential data points with your own.** We have removed sensitive keys and hardcoded data to protect privacy and prevent misuse. 

Please perform the following replacements before building:

1. **Google Maps API Key:** 
   - Open `frontend/android/app/src/main/AndroidManifest.xml`
   - Replace `YOUR_API_KEY_HERE` with your actual Google Maps API Key.
   
2. **Local Environment IP:**
   - Open `frontend/lib/core/config/app_config.dart`
   - Replace `http://YOUR_LOCAL_IP:5002` with the local IP address of your backend server for testing on real devices.

3. **Emergency SOS Numbers:**
   - Open `frontend/lib/features/safepulse/services/sos_service.dart`
   - Replace the default placeholders (`+YOUR_COUNTRY_CODE_YOUR_NUMBER_1`, etc.) in `emergencyContacts` with your real emergency testing numbers.

4. **Environment Variables:**
   - In the `backend` folder, duplicate `.env.example` as `.env` and fill in your actual credentials (MongoDB URI, JWT secret, Twilio credentials if using SMS APIs).

---

## 🏗️ Architecture

SafePulse uses a robust, scalable multi-service architecture:

- **`frontend/`** - Flutter mobile application featuring provider/repository/service separation.
- **`backend/`** - Node.js API gateway managing auth, circles, route scoring, real-time WebSockets, alerts, and acting as an AI proxy.
- **`backend-springboot/`** - Spring Boot emergency-event microservice with JPA persistence.
- **`ai-service/`** - Python FastAPI accident-analysis microservice employing TensorFlow Lite models.
- **`.github/workflows/ci.yml`** - GitHub Actions ensuring continuous integration for all services.

## 🚀 Local Development

### 1. Node.js Backend

```powershell
cd backend
npm install
npm test
npm start
```

### 2. Spring Boot Emergency Service

```powershell
cd backend-springboot
.\mvnw.cmd test
.\mvnw.cmd spring-boot:run
```

### 3. Python AI Service

```powershell
cd ai-service
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 7000
```
*(Run unit tests using: `PYTHONPATH='P:\SafePulse\ai-service' python -m unittest discover -s tests`)*

### 4. Flutter Frontend

```powershell
cd frontend
flutter pub get
flutter test
flutter run --dart-define=BASE_URL=http://<backend-host>:5000
```

> **Note:** `frontend/packages/telephony_fix` is a custom local plugin ensuring offline emergency SMS fallback functions perfectly.

## ✅ Production Readiness

- **Secrets Management:** Keep secrets strictly in `.env` files.
- **Security:** Node.js utilizes Helmet and rate limiting.
- **Database:** Deploy MongoDB with geospatial indexing and switch the Spring Boot service to MySQL/PostgreSQL.
- **Routing:** Switch public OSRM endpoints to a self-hosted or premium routing provider to handle production scale.

<div align="center">
  <i>Stay Safe, Stay Connected.</i>
</div>

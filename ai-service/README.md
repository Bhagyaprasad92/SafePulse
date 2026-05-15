# SafePulse AI Accident Analysis Service

This microservice performs server-side accident analysis for SafePulse. It accepts a sliding window of accelerometer, gyroscope, and optional speed samples, runs the bundled TensorFlow Lite crash model when available, and falls back to a calibrated heuristic when the runtime is unavailable.

## Endpoints

- `GET /health` returns service and model status.
- `GET /v1/model/metadata` returns model path, expected window size, features, and runtime mode.
- `POST /v1/accident/analyze` accepts sensor samples and returns crash probability, severity, calibration notes, and false-positive risk.

## Local Run

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 7000
```

By default the service loads `../frontend/assets/crash_model.tflite`. Override this with `CRASH_MODEL_PATH`.

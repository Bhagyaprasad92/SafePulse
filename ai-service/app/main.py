from fastapi import FastAPI

from app.schemas import AccidentAnalysisRequest, AccidentAnalysisResponse
from app.services.crash_analyzer import CrashAnalyzer, SensorReading

app = FastAPI(
    title="SafePulse AI Accident Analysis Service",
    version="1.0.0",
    description="Server-side TensorFlow Lite crash analysis and phone-drop filtering.",
)

analyzer = CrashAnalyzer()


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "model": analyzer.model_metadata()}


@app.get("/v1/model/metadata")
def model_metadata() -> dict:
    return analyzer.model_metadata()


@app.post("/v1/accident/analyze", response_model=AccidentAnalysisResponse)
def analyze_accident(payload: AccidentAnalysisRequest) -> dict:
    readings = [
        SensorReading(
            ax=sample.ax,
            ay=sample.ay,
            az=sample.az,
            gx=sample.gx,
            gy=sample.gy,
            gz=sample.gz,
            speed_kmh=sample.speedKmh,
        )
        for sample in payload.samples
    ]
    return analyzer.analyze(readings)

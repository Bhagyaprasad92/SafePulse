from typing import List, Optional

from pydantic import BaseModel, Field


class SensorSample(BaseModel):
    ax: float = Field(description="Linear acceleration on X axis in m/s^2")
    ay: float = Field(description="Linear acceleration on Y axis in m/s^2")
    az: float = Field(description="Linear acceleration on Z axis in m/s^2")
    gx: float = Field(default=0.0, description="Gyroscope X axis in rad/s")
    gy: float = Field(default=0.0, description="Gyroscope Y axis in rad/s")
    gz: float = Field(default=0.0, description="Gyroscope Z axis in rad/s")
    speedKmh: Optional[float] = Field(default=None, description="Vehicle speed when available")
    timestampMs: Optional[int] = Field(default=None)


class AccidentAnalysisRequest(BaseModel):
    tripId: Optional[str] = None
    userId: Optional[str] = None
    samples: List[SensorSample] = Field(min_length=1)


class AccidentAnalysisResponse(BaseModel):
    crashDetected: bool
    crashProbability: float
    severity: str
    maxGForce: float
    falsePositiveRisk: str
    modelUsed: str
    reason: str
    calibration: List[str]

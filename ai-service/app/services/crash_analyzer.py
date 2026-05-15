from __future__ import annotations

import math
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Optional


@dataclass(frozen=True)
class SensorReading:
    ax: float
    ay: float
    az: float
    gx: float = 0.0
    gy: float = 0.0
    gz: float = 0.0
    speed_kmh: Optional[float] = None


class CrashAnalyzer:
    """TFLite-first crash analyzer with a deterministic safety fallback."""

    def __init__(self, model_path: Optional[str] = None, window_size: int = 250) -> None:
        default_model = Path(__file__).resolve().parents[3] / "frontend" / "assets" / "crash_model.tflite"
        self.model_path = Path(model_path or os.getenv("CRASH_MODEL_PATH", default_model))
        self.window_size = window_size
        self._interpreter = None
        self._runtime_name = "heuristic"
        self._load_interpreter()

    @property
    def runtime_name(self) -> str:
        return self._runtime_name

    def model_metadata(self) -> dict:
        return {
            "modelPath": str(self.model_path),
            "modelPresent": self.model_path.exists(),
            "runtime": self.runtime_name,
            "windowSize": self.window_size,
            "features": ["ax", "ay", "az", "gx", "gy", "gz"],
        }

    def analyze(self, readings: Iterable[SensorReading]) -> dict:
        window = list(readings)[-self.window_size :]
        if not window:
            return self._response(False, 0.0, 0.0, "LOW", "No sensor readings received", [])

        max_g = max(self._g_force(reading) for reading in window)
        max_rotation = max(self._rotation(reading) for reading in window)
        speed_values = [reading.speed_kmh for reading in window if reading.speed_kmh is not None]
        max_speed = max(speed_values) if speed_values else 0.0

        calibration = self._calibration_notes(max_g, max_rotation, max_speed, len(window))

        tflite_probability = self._run_tflite(window)
        if tflite_probability is not None:
            probability = self._blend_model_with_context(tflite_probability, max_g, max_speed)
            reason = "TFLite model inference blended with speed and impact context"
            return self._classified_response(probability, max_g, reason, calibration, "tflite")

        probability = self._heuristic_probability(max_g, max_rotation, max_speed, len(window))
        reason = "Heuristic fallback used because TensorFlow Lite runtime is unavailable"
        return self._classified_response(probability, max_g, reason, calibration, "heuristic")

    def _load_interpreter(self) -> None:
        if not self.model_path.exists():
            return

        interpreter_cls = None
        try:
            from tflite_runtime.interpreter import Interpreter  # type: ignore

            interpreter_cls = Interpreter
            self._runtime_name = "tflite-runtime"
        except Exception:
            try:
                from tensorflow.lite import Interpreter  # type: ignore

                interpreter_cls = Interpreter
                self._runtime_name = "tensorflow-lite"
            except Exception:
                self._runtime_name = "heuristic"
                return

        try:
            self._interpreter = interpreter_cls(model_path=str(self.model_path))
            self._interpreter.allocate_tensors()
        except Exception:
            self._interpreter = None
            self._runtime_name = "heuristic"

    def _run_tflite(self, window: List[SensorReading]) -> Optional[float]:
        if self._interpreter is None:
            return None

        try:
            import numpy as np

            padded = self._pad_window(window)
            tensor = np.array(
                [[[r.ax, r.ay, r.az, r.gx, r.gy, r.gz] for r in padded]],
                dtype=np.float32,
            )
            input_details = self._interpreter.get_input_details()
            output_details = self._interpreter.get_output_details()
            self._interpreter.set_tensor(input_details[0]["index"], tensor)
            self._interpreter.invoke()
            output = self._interpreter.get_tensor(output_details[0]["index"])
            return float(output.reshape(-1)[0])
        except Exception:
            return None

    def _pad_window(self, window: List[SensorReading]) -> List[SensorReading]:
        if len(window) >= self.window_size:
            return window[-self.window_size :]

        pad = [window[0]] * (self.window_size - len(window))
        return pad + window

    def _heuristic_probability(
        self,
        max_g: float,
        max_rotation: float,
        max_speed: float,
        sample_count: int,
    ) -> float:
        impact_score = min(1.0, max(0.0, (max_g - 2.0) / 3.0))
        speed_score = min(1.0, max_speed / 45.0)
        stability_score = 1.0 if sample_count >= 40 else sample_count / 40.0
        phone_drop_penalty = 0.25 if max_speed < 8 and max_rotation > 5 else 0.0

        probability = (impact_score * 0.58) + (speed_score * 0.27) + (stability_score * 0.15)
        return max(0.0, min(1.0, probability - phone_drop_penalty))

    def _blend_model_with_context(self, model_probability: float, max_g: float, max_speed: float) -> float:
        context_probability = self._heuristic_probability(max_g, 0.0, max_speed, self.window_size)
        return max(0.0, min(1.0, model_probability * 0.7 + context_probability * 0.3))

    def _classified_response(
        self,
        probability: float,
        max_g: float,
        reason: str,
        calibration: List[str],
        model_used: str,
    ) -> dict:
        if probability >= 0.78 or max_g >= 4.2:
            severity = "CRITICAL"
        elif probability >= 0.55 or max_g >= 3.2:
            severity = "HIGH"
        elif probability >= 0.35:
            severity = "MEDIUM"
        else:
            severity = "LOW"

        detected = probability >= 0.55 or max_g >= 3.5
        false_positive_risk = "HIGH" if max_g > 3 and probability < 0.45 else "LOW"
        return self._response(detected, probability, max_g, false_positive_risk, reason, calibration, severity, model_used)

    def _response(
        self,
        crash_detected: bool,
        probability: float,
        max_g: float,
        false_positive_risk: str,
        reason: str,
        calibration: List[str],
        severity: str = "LOW",
        model_used: str = "heuristic",
    ) -> dict:
        return {
            "crashDetected": crash_detected,
            "crashProbability": round(probability, 4),
            "severity": severity,
            "maxGForce": round(max_g, 3),
            "falsePositiveRisk": false_positive_risk,
            "modelUsed": model_used,
            "reason": reason,
            "calibration": calibration,
        }

    def _calibration_notes(self, max_g: float, max_rotation: float, max_speed: float, sample_count: int) -> List[str]:
        notes = []
        notes.append(f"Window contains {sample_count} samples; target is {self.window_size}.")
        notes.append(f"Peak impact force is {max_g:.2f}G.")
        if max_speed < 8 and max_rotation > 5:
            notes.append("High rotation with low speed is treated as possible phone drop.")
        if max_speed >= 20 and max_g >= 3:
            notes.append("High vehicle speed plus impact increases accident confidence.")
        return notes

    @staticmethod
    def _g_force(reading: SensorReading) -> float:
        return math.sqrt(reading.ax**2 + reading.ay**2 + reading.az**2) / 9.81

    @staticmethod
    def _rotation(reading: SensorReading) -> float:
        return math.sqrt(reading.gx**2 + reading.gy**2 + reading.gz**2)

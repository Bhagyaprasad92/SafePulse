import unittest

from app.services.crash_analyzer import CrashAnalyzer, SensorReading


class CrashAnalyzerTest(unittest.TestCase):
    def setUp(self):
        self.analyzer = CrashAnalyzer(model_path="missing-model.tflite")

    def test_detects_high_speed_impact(self):
        samples = [SensorReading(ax=0.1, ay=0.2, az=9.8, speed_kmh=42) for _ in range(60)]
        samples.append(SensorReading(ax=42.0, ay=8.0, az=18.0, speed_kmh=44))

        result = self.analyzer.analyze(samples)

        self.assertTrue(result["crashDetected"])
        self.assertIn(result["severity"], {"HIGH", "CRITICAL"})
        self.assertEqual(result["falsePositiveRisk"], "LOW")

    def test_filters_stationary_phone_drop(self):
        samples = [SensorReading(ax=0.1, ay=0.2, az=9.8, gx=0.1, gy=0.1, gz=0.1, speed_kmh=0) for _ in range(60)]
        samples.append(SensorReading(ax=32.0, ay=3.0, az=8.0, gx=6.0, gy=4.0, gz=3.0, speed_kmh=0))

        result = self.analyzer.analyze(samples)

        self.assertFalse(result["crashDetected"])
        self.assertEqual(result["falsePositiveRisk"], "HIGH")
        self.assertTrue(any("phone drop" in note for note in result["calibration"]))


if __name__ == "__main__":
    unittest.main()

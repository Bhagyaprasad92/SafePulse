package com.safepulse.backend.service;

import com.safepulse.backend.dto.SosRequest;
import com.safepulse.backend.model.EmergencyEvent;
import com.safepulse.backend.repository.EmergencyEventRepository;
import java.util.List;
import java.util.Locale;
import java.util.NoSuchElementException;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class EmergencyResponseService {

    private final EmergencyEventRepository repository;

    public EmergencyResponseService(EmergencyEventRepository repository) {
        this.repository = repository;
    }

    @Transactional
    public EmergencyEvent createEvent(SosRequest request) {
        validateCoordinates(request.getLatitude(), request.getLongitude());

        EmergencyEvent event = new EmergencyEvent();
        event.setEventId(normalizeEventId(request.getEventId()));
        event.setLatitude(request.getLatitude());
        event.setLongitude(request.getLongitude());
        event.setSeverity(normalizeSeverity(request.getSeverity()));
        event.setLocationStatus(normalizeLocationStatus(request.getLocationStatus()));
        event.setStatus("ACTIVE");
        event.setPriorityScore(priorityScore(event.getSeverity(), event.getLocationStatus()));
        event.setDispatchRecommended(event.getPriorityScore() >= 80);

        return repository.save(event);
    }

    @Transactional(readOnly = true)
    public EmergencyEvent getEvent(String eventId) {
        return repository.findByEventId(eventId)
                .orElseThrow(() -> new NoSuchElementException("Emergency event not found"));
    }

    @Transactional(readOnly = true)
    public List<EmergencyEvent> getActiveEvents() {
        return repository.findByStatusOrderByCreatedAtDesc("ACTIVE");
    }

    @Transactional
    public EmergencyEvent resolveEvent(String eventId) {
        EmergencyEvent event = getEvent(eventId);
        event.setStatus("RESOLVED");
        event.setDispatchRecommended(false);
        return repository.save(event);
    }

    private void validateCoordinates(double latitude, double longitude) {
        if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
            throw new IllegalArgumentException("latitude/longitude are outside valid ranges");
        }
    }

    private String normalizeEventId(String eventId) {
        if (eventId == null || eventId.isBlank()) {
            return "EVT-" + UUID.randomUUID();
        }
        return eventId.trim();
    }

    private String normalizeSeverity(String severity) {
        if (severity == null || severity.isBlank()) {
            return "MEDIUM";
        }
        return severity.trim().toUpperCase(Locale.ROOT);
    }

    private String normalizeLocationStatus(String locationStatus) {
        if (locationStatus == null || locationStatus.isBlank()) {
            return "UNKNOWN";
        }
        return locationStatus.trim().toUpperCase(Locale.ROOT);
    }

    private int priorityScore(String severity, String locationStatus) {
        int base = switch (severity) {
            case "CRITICAL" -> 100;
            case "HIGH" -> 85;
            case "MEDIUM" -> 60;
            case "LOW" -> 35;
            default -> 50;
        };

        if ("UNAVAILABLE".equals(locationStatus) || "STALE".equals(locationStatus)) {
            return Math.max(0, base - 15);
        }
        return base;
    }
}

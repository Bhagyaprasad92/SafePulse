package com.safepulse.backend.dto;

import com.safepulse.backend.model.EmergencyEvent;
import java.time.Instant;

public class EmergencyEventResponse {

    private String eventId;
    private double latitude;
    private double longitude;
    private String severity;
    private String locationStatus;
    private String status;
    private int priorityScore;
    private boolean dispatchRecommended;
    private Instant createdAt;
    private Instant updatedAt;

    public static EmergencyEventResponse from(EmergencyEvent event) {
        EmergencyEventResponse response = new EmergencyEventResponse();
        response.eventId = event.getEventId();
        response.latitude = event.getLatitude();
        response.longitude = event.getLongitude();
        response.severity = event.getSeverity();
        response.locationStatus = event.getLocationStatus();
        response.status = event.getStatus();
        response.priorityScore = event.getPriorityScore();
        response.dispatchRecommended = event.isDispatchRecommended();
        response.createdAt = event.getCreatedAt();
        response.updatedAt = event.getUpdatedAt();
        return response;
    }

    public String getEventId() {
        return eventId;
    }

    public double getLatitude() {
        return latitude;
    }

    public double getLongitude() {
        return longitude;
    }

    public String getSeverity() {
        return severity;
    }

    public String getLocationStatus() {
        return locationStatus;
    }

    public String getStatus() {
        return status;
    }

    public int getPriorityScore() {
        return priorityScore;
    }

    public boolean isDispatchRecommended() {
        return dispatchRecommended;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}

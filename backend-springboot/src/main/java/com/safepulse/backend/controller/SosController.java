package com.safepulse.backend.controller;

import com.safepulse.backend.dto.EmergencyEventResponse;
import com.safepulse.backend.dto.SosRequest;
import com.safepulse.backend.service.EmergencyResponseService;
import java.util.List;
import java.util.NoSuchElementException;
import java.util.stream.Collectors;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/sos")
public class SosController {

    private final EmergencyResponseService emergencyResponseService;

    public SosController(EmergencyResponseService emergencyResponseService) {
        this.emergencyResponseService = emergencyResponseService;
    }

    @PostMapping
    public ResponseEntity<EmergencyEventResponse> receiveSOS(@RequestBody SosRequest request) {
        return ResponseEntity.status(201)
                .body(EmergencyEventResponse.from(emergencyResponseService.createEvent(request)));
    }

    @GetMapping("/{eventId}")
    public ResponseEntity<EmergencyEventResponse> getSOS(@PathVariable String eventId) {
        return ResponseEntity.ok(EmergencyEventResponse.from(emergencyResponseService.getEvent(eventId)));
    }

    @GetMapping("/active")
    public ResponseEntity<List<EmergencyEventResponse>> activeSOS() {
        List<EmergencyEventResponse> activeEvents = emergencyResponseService.getActiveEvents()
                .stream()
                .map(EmergencyEventResponse::from)
                .collect(Collectors.toList());
        return ResponseEntity.ok(activeEvents);
    }

    @PatchMapping("/{eventId}/resolve")
    public ResponseEntity<EmergencyEventResponse> resolveSOS(@PathVariable String eventId) {
        return ResponseEntity.ok(EmergencyEventResponse.from(emergencyResponseService.resolveEvent(eventId)));
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<String> handleBadRequest(IllegalArgumentException error) {
        return ResponseEntity.badRequest().body(error.getMessage());
    }

    @ExceptionHandler(NoSuchElementException.class)
    public ResponseEntity<String> handleNotFound(NoSuchElementException error) {
        return ResponseEntity.status(404).body(error.getMessage());
    }
}

package com.safepulse.backend.service;

import com.safepulse.backend.dto.SosRequest;
import com.safepulse.backend.model.EmergencyEvent;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.annotation.Transactional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest
@Transactional
class EmergencyResponseServiceTest {

    @Autowired
    private EmergencyResponseService service;

    @Test
    void createEventCalculatesPriority() {
        SosRequest request = new SosRequest();
        request.setEventId("EVT-SERVICE-001");
        request.setLatitude(17.0);
        request.setLongitude(78.0);
        request.setSeverity("critical");
        request.setLocationStatus("accurate");

        EmergencyEvent event = service.createEvent(request);

        assertEquals("CRITICAL", event.getSeverity());
        assertEquals(100, event.getPriorityScore());
        assertTrue(event.isDispatchRecommended());
    }

    @Test
    void createEventRejectsInvalidCoordinates() {
        SosRequest request = new SosRequest();
        request.setEventId("EVT-SERVICE-002");
        request.setLatitude(200.0);
        request.setLongitude(78.0);
        request.setSeverity("HIGH");
        request.setLocationStatus("ACCURATE");

        assertThrows(IllegalArgumentException.class, () -> service.createEvent(request));
    }
}

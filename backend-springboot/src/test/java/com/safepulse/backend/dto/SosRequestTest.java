package com.safepulse.backend.dto;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertEquals;

class SosRequestTest {

    @Test
    void testGettersAndSetters() {
        SosRequest request = new SosRequest();
        
        request.setEventId("EVT-123");
        request.setLatitude(40.7128);
        request.setLongitude(-74.0060);
        request.setSeverity("HIGH");
        request.setLocationStatus("ACCURATE");
        
        assertEquals("EVT-123", request.getEventId());
        assertEquals(40.7128, request.getLatitude());
        assertEquals(-74.0060, request.getLongitude());
        assertEquals("HIGH", request.getSeverity());
        assertEquals("ACCURATE", request.getLocationStatus());
    }
}

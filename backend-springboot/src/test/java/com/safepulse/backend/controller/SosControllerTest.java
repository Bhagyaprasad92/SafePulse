package com.safepulse.backend.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.safepulse.backend.dto.SosRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class SosControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void receiveSOSPersistsEmergencyEvent() throws Exception {
        SosRequest request = new SosRequest();
        request.setEventId("EVT-SPRING-001");
        request.setLatitude(17.3850);
        request.setLongitude(78.4867);
        request.setSeverity("HIGH");
        request.setLocationStatus("ACCURATE");

        mockMvc.perform(post("/api/sos")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.eventId").value("EVT-SPRING-001"))
                .andExpect(jsonPath("$.status").value("ACTIVE"))
                .andExpect(jsonPath("$.priorityScore").value(85))
                .andExpect(jsonPath("$.dispatchRecommended").value(true));
    }

    @Test
    void activeSOSReturnsPersistedEvents() throws Exception {
        SosRequest request = new SosRequest();
        request.setEventId("EVT-SPRING-002");
        request.setLatitude(16.5060);
        request.setLongitude(80.6480);
        request.setSeverity("CRITICAL");
        request.setLocationStatus("ACCURATE");

        mockMvc.perform(post("/api/sos")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated());

        mockMvc.perform(get("/api/sos/active"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)))
                .andExpect(jsonPath("$[0].eventId").value("EVT-SPRING-002"));
    }

    @Test
    void resolveSOSClosesActiveEvent() throws Exception {
        SosRequest request = new SosRequest();
        request.setEventId("EVT-SPRING-003");
        request.setLatitude(17.4100);
        request.setLongitude(78.4600);
        request.setSeverity("MEDIUM");
        request.setLocationStatus("ACCURATE");

        mockMvc.perform(post("/api/sos")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated());

        mockMvc.perform(patch("/api/sos/EVT-SPRING-003/resolve"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("RESOLVED"))
                .andExpect(jsonPath("$.dispatchRecommended").value(false));
    }
}

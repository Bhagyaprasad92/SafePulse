package com.safepulse.backend.repository;

import com.safepulse.backend.model.EmergencyEvent;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface EmergencyEventRepository extends JpaRepository<EmergencyEvent, Long> {
    Optional<EmergencyEvent> findByEventId(String eventId);

    List<EmergencyEvent> findByStatusOrderByCreatedAtDesc(String status);
}

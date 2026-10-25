package dev.attendly.server;
import java.util.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.dao.DataIntegrityViolationException;
@RestControllerAdvice
class ApiErrors {
 @ExceptionHandler(ResponseStatusException.class) ResponseEntity<?> status(ResponseStatusException e) {return ResponseEntity.status(e.getStatusCode()).body(Map.of("message",Objects.requireNonNullElse(e.getReason(),"Request failed.")));}
 @ExceptionHandler(MethodArgumentNotValidException.class) ResponseEntity<?> invalid() {return ResponseEntity.badRequest().body(Map.of("message","Check the fields and try again. Passwords must contain 8–72 characters."));}
 @ExceptionHandler(DataIntegrityViolationException.class) ResponseEntity<?> duplicate() {return ResponseEntity.status(409).body(Map.of("message","This account or IMS identity is already registered."));}
}

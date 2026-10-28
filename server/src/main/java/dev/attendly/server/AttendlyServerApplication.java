package dev.attendly.server;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication(exclude = org.springframework.boot.security.autoconfigure.UserDetailsServiceAutoConfiguration.class)
public class AttendlyServerApplication {

	public static void main(String[] args) {
		SpringApplication.run(AttendlyServerApplication.class, args);
	}

}

package dev.attendly.server;
import java.util.*;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.*;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.csrf.HttpSessionCsrfTokenRepository;
import org.springframework.security.oauth2.client.registration.ClientRegistrationRepository;
import org.springframework.security.oauth2.client.oidc.userinfo.OidcUserService;
import org.springframework.security.oauth2.core.*;
import org.springframework.web.cors.*;
@Configuration
class SecurityConfig {
 @Bean PasswordEncoder passwordEncoder() { return new BCryptPasswordEncoder(12); }
 @Bean SecurityFilterChain security(HttpSecurity http, ObjectProvider<ClientRegistrationRepository> clients, Accounts accounts,
       @Value("${attendly.web-origin}") String origin) throws Exception {
   var cors=new CorsConfiguration(); cors.setAllowedOrigins(List.of(origin)); cors.setAllowedMethods(List.of("GET","POST","DELETE","OPTIONS"));
   cors.setAllowedHeaders(List.of("Content-Type","X-CSRF-TOKEN")); cors.setAllowCredentials(true);
   var source=new UrlBasedCorsConfigurationSource(); source.registerCorsConfiguration("/**",cors);
   http.cors(c->c.configurationSource(source))
    .csrf(c->c.csrfTokenRepository(new HttpSessionCsrfTokenRepository()))
    .authorizeHttpRequests(a->a.requestMatchers("/","/index.html","/flutter*","/main.dart.js","/manifest.json","/precache-manifest.json","/service-worker.js","/assets/**","/canvaskit/**","/icons/**","/favicon.png","/version.json","/api/config","/api/auth/csrf","/api/auth/signup","/api/auth/login","/error","/oauth2/**","/login/**").permitAll().anyRequest().authenticated())
    .requestCache(c->c.disable())
    .exceptionHandling(e->e.authenticationEntryPoint((req,res,ex)->{res.setStatus(401);res.setContentType("application/json");res.getWriter().write("{\"message\":\"Sign in to Attendly.\"}");}))
    .logout(l->l.logoutUrl("/api/auth/logout").deleteCookies("JSESSIONID").logoutSuccessHandler((req,res,a)->res.setStatus(204)));
   if(clients.getIfAvailable()!=null) {
     var delegate=new OidcUserService();
     http.oauth2Login(o->o.userInfoEndpoint(u->u.oidcUserService(request->{
       var user=delegate.loadUser(request);
       if(!Boolean.TRUE.equals(user.getEmailVerified())) throw new OAuth2AuthenticationException(new OAuth2Error("unverified_email"));
       if(accounts.find("google_subject",user.getSubject()).isEmpty()) {
         String email=user.getEmail().toLowerCase(Locale.ROOT);
         // Never silently attach Google to an existing password account by email.
         if(accounts.find("email",email).isPresent()) throw new OAuth2AuthenticationException(new OAuth2Error("account_link_required"));
         accounts.create(email,Objects.requireNonNullElse(user.getFullName(),"Student"),null,user.getSubject());
       }
       return user;
     })).defaultSuccessUrl(origin,true).failureUrl(origin+"/?authError=google"));
   }
   return http.build();
 }
}

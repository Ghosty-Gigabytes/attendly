package dev.attendly.server;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.*;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.csrf.HttpSessionCsrfTokenRepository;
import org.springframework.web.cors.*;
@Configuration
class SecurityConfig {
 @Bean SecurityFilterChain security(HttpSecurity http,
       @Value("${attendly.web-origin}") String origin) throws Exception {
   var cors=new CorsConfiguration(); cors.setAllowedOrigins(List.of(origin.replaceAll("/+$",""))); cors.setAllowedMethods(List.of("GET","POST","DELETE","OPTIONS"));
   cors.setAllowedHeaders(List.of("Content-Type","X-CSRF-TOKEN")); cors.setAllowCredentials(true);
   var source=new UrlBasedCorsConfigurationSource(); source.registerCorsConfiguration("/**",cors);
   http.cors(c->c.configurationSource(source))
    .csrf(c->c.csrfTokenRepository(new HttpSessionCsrfTokenRepository()))
    .addFilterBefore(new org.springframework.web.filter.OncePerRequestFilter(){
      @Override protected void doFilterInternal(jakarta.servlet.http.HttpServletRequest req,jakarta.servlet.http.HttpServletResponse res,jakarta.servlet.FilterChain chain) throws java.io.IOException,jakarta.servlet.ServletException {
        var session=req.getSession(false);String path=req.getRequestURI();
        if(session!=null&&Boolean.TRUE.equals(session.getAttribute("limited"))&&path.startsWith("/api/")&&!req.getMethod().equals("GET")
          &&!Set.of("/api/auth/ims/login","/api/auth/ims/challenge","/api/auth/logout").contains(path)){
          res.setStatus(403);res.setContentType("application/json");res.getWriter().write("{\"message\":\"IMS is unavailable. You can view saved records; sign in with IMS again to make changes.\"}");return;
        }
        chain.doFilter(req,res);
      }
    },org.springframework.security.web.access.intercept.AuthorizationFilter.class)
    .authorizeHttpRequests(a->a.requestMatchers("/","/index.html","/flutter*","/main.dart.js","/manifest.json","/precache-manifest.json","/service-worker.js","/assets/**","/canvaskit/**","/icons/**","/favicon.png","/version.json","/api/auth/csrf","/api/auth/ims/**","/error").permitAll().anyRequest().authenticated())
    .requestCache(c->c.disable())
    .exceptionHandling(e->e.accessDeniedHandler((req,res,ex)->{
      res.setStatus(403);res.setContentType("application/json");
      res.getWriter().write(ex instanceof org.springframework.security.web.csrf.CsrfException
        ? "{\"code\":\"CSRF_INVALID\",\"message\":\"Your session security token expired. Please retry.\"}"
        : "{\"message\":\"This request is not allowed.\"}");
    }).authenticationEntryPoint((req,res,ex)->{res.setStatus(401);res.setContentType("application/json");res.getWriter().write("{\"message\":\"Sign in to Attendly.\"}");}))
    .logout(l->l.logoutUrl("/api/auth/logout").deleteCookies("JSESSIONID").logoutSuccessHandler((req,res,a)->res.setStatus(204)));
   return http.build();
 }
}

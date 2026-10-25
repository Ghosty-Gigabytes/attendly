package dev.attendly.server;
import java.util.*;
import jakarta.servlet.http.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.security.core.*;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.context.HttpSessionSecurityContextRepository;
import org.springframework.security.web.csrf.CsrfToken;
import org.springframework.security.oauth2.client.registration.ClientRegistrationRepository;
import static org.springframework.http.HttpStatus.*;
@RestController
class AuthApi {
 private final Accounts accounts; private final PasswordEncoder passwords; private final boolean google;
 private final String dummy;
 AuthApi(Accounts a,PasswordEncoder p,ObjectProvider<ClientRegistrationRepository> clients) {accounts=a;passwords=p;google=clients.getIfAvailable()!=null;dummy=p.encode(UUID.randomUUID().toString());}
 record Signup(@Email @NotBlank @Size(max=254) String email,@NotBlank @Size(min=8,max=72) String password,@NotBlank @Size(max=100) String name) {}
 record Login(@Email @NotBlank @Size(max=254) String email,@NotBlank @Size(max=72) String password) {}
 @GetMapping("/api/config") Map<String,Object> config() { return Map.of("googleEnabled",google); }
 @GetMapping("/api/auth/csrf") Map<String,String> csrf(CsrfToken token) {return Map.of("token",token.getToken(),"header",token.getHeaderName());}
 @GetMapping("/api/auth/me") Map<String,Object> me(Authentication auth) {return accounts.current(auth).publicView();}
 @PostMapping("/api/auth/signup") Map<String,Object> signup(@Valid @RequestBody Signup body,HttpServletRequest req,HttpServletResponse res) {
   if(body.password().getBytes(java.nio.charset.StandardCharsets.UTF_8).length>72)throw new ResponseStatusException(BAD_REQUEST,"Use a password of at most 72 UTF-8 bytes.");
   String email=body.email().trim().toLowerCase(Locale.ROOT);
   if(accounts.find("email",email).isPresent()) throw new ResponseStatusException(CONFLICT,"An account already uses this email. Sign in instead.");
   var account=accounts.create(email,body.name().trim(),passwords.encode(body.password()),null); establish(account,req,res); return account.publicView();
 }
 @PostMapping("/api/auth/login") Map<String,Object> login(@Valid @RequestBody Login body,HttpServletRequest req,HttpServletResponse res) {
   if(body.password().getBytes(java.nio.charset.StandardCharsets.UTF_8).length>72)throw new ResponseStatusException(UNAUTHORIZED,"Email or password was not accepted.");
   var found=accounts.find("email",body.email().trim().toLowerCase(Locale.ROOT));
   boolean valid=passwords.matches(body.password(),found.map(Accounts.Account::hash).orElse(dummy));
   if(!valid || found.isEmpty()) throw new ResponseStatusException(UNAUTHORIZED,"Email or password was not accepted.");
   establish(found.get(),req,res);return found.get().publicView();
 }
 private void establish(Accounts.Account account,HttpServletRequest req,HttpServletResponse res) {
   req.getSession();req.changeSessionId();
   var context=SecurityContextHolder.createEmptyContext();
   context.setAuthentication(UsernamePasswordAuthenticationToken.authenticated(account.id(),null,List.of(new SimpleGrantedAuthority("ROLE_USER"))));
   SecurityContextHolder.setContext(context);new HttpSessionSecurityContextRepository().saveContext(context,req,res);
 }
}

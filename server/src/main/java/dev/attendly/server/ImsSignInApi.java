package dev.attendly.server;
import java.time.*;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import jakarta.servlet.http.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import static org.springframework.http.HttpStatus.*;

@RestController
class ImsSignInApi {
 final ImsAccounts logins;final ImsService ims;final Accounts accounts;
 final Map<String,Window> limits=new ConcurrentHashMap<>();
 record Window(Instant at,int count){}
 ImsSignInApi(ImsAccounts l,ImsService i,Accounts a){logins=l;ims=i;accounts=a;}
 record Login(@NotBlank @Pattern(regexp="[A-Za-z0-9-]{4,40}") String studentId,@NotBlank @Size(max=256) String password,
   @Size(max=100) String challenge,@Size(max=16) String captcha,boolean remember){}
 String flow(HttpServletRequest request){var session=request.getSession();String key=(String)session.getAttribute("imsFlow");if(key==null){key=UUID.randomUUID().toString();session.setAttribute("imsFlow",key);}return key;}
 synchronized void throttle(String key,int max){
   Instant now=Instant.now();limits.entrySet().removeIf(e->e.getValue().at().isBefore(now.minusSeconds(900)));
   var value=limits.get(key);if(value==null)value=new Window(now,0);
   if(value.count()>=max)throw new ResponseStatusException(TOO_MANY_REQUESTS,"Too many attempts. Please wait 15 minutes.");
   limits.put(key,new Window(value.at(),value.count()+1));
 }
 @PostMapping("/api/auth/ims/challenge") Map<String,Object> challenge(HttpServletRequest request) throws Exception {
   throttle("challenge:"+request.getRemoteAddr(),300);
   return ims.challenge(flow(request));
 }
 @PostMapping("/api/auth/ims/login") Map<String,Object> login(@Valid @RequestBody Login body,HttpServletRequest req,HttpServletResponse res) throws Exception {
   String student=body.studentId().trim().toUpperCase(Locale.ROOT);
   throttle("ip:"+req.getRemoteAddr(),120);throttle("student:"+student,8);
   var result=logins.login(flow(req),body.challenge(),student,body.password(),body.captcha(),body.remember());
   AuthApi.establish(result.account(),req,res);
   req.getSession().setAttribute("limited",result.limited());
   req.getSession().setMaxInactiveInterval(result.limited()?900:604800);
   var view=new LinkedHashMap<>(result.account().publicView());view.put("studentId",student);view.put("limited",result.limited());view.put("rememberIms",logins.remembers(result.account().id()));
   return view;
 }
 @PostMapping("/api/ims/forget-password") void forget(Authentication auth){logins.forget(accounts.current(auth).id());}
}

package dev.attendly.server;
import java.util.*;
import jakarta.servlet.http.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.core.*;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.web.context.HttpSessionSecurityContextRepository;
import org.springframework.security.web.csrf.CsrfToken;
@RestController
class AuthApi {
 private final Accounts accounts;
 private final org.springframework.jdbc.core.simple.JdbcClient sql;
 AuthApi(Accounts accounts,org.springframework.jdbc.core.simple.JdbcClient sql){this.accounts=accounts;this.sql=sql;}
 @GetMapping("/api/auth/csrf") Map<String,String> csrf(CsrfToken token) {return Map.of("token",token.getToken(),"header",token.getHeaderName());}
 @GetMapping("/api/auth/me") Map<String,Object> me(Authentication auth,HttpServletRequest request) {
   var account=accounts.current(auth);var view=new LinkedHashMap<>(account.publicView());
   var credentials=sql.sql("SELECT student_id,password_cipher FROM ims_credentials WHERE owner_id=:o").param("o",account.id())
     .query((r,n)->Map.of("studentId",r.getString("student_id"),"rememberIms",r.getString("password_cipher")!=null)).optional();
   credentials.ifPresent(view::putAll);var session=request.getSession(false);
   view.put("limited",session!=null&&Boolean.TRUE.equals(session.getAttribute("limited")));return view;
 }
 static void establish(Accounts.Account account,HttpServletRequest req,HttpServletResponse res) {
   req.getSession();req.changeSessionId();
   req.getSession().removeAttribute("limited");
   var context=SecurityContextHolder.createEmptyContext();
   context.setAuthentication(UsernamePasswordAuthenticationToken.authenticated(account.id(),null,List.of(new SimpleGrantedAuthority("ROLE_USER"))));
   SecurityContextHolder.setContext(context);new HttpSessionSecurityContextRepository().saveContext(context,req,res);
 }
}

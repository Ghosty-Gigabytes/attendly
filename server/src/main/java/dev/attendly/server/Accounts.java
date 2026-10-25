package dev.attendly.server;
import java.time.Instant;
import java.util.*;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.core.oidc.user.OidcUser;
import org.springframework.web.server.ResponseStatusException;
import static org.springframework.http.HttpStatus.*;
@Service
class Accounts {
 final JdbcClient sql;
 Accounts(JdbcClient sql) { this.sql=sql; }
 record Account(String id,String email,String name,String hash,String googleSubject) {
   Map<String,Object> publicView() { return Map.of("id",id,"email",email,"name",name); }
 }
 Optional<Account> find(String column,String value) {
   if(!Set.of("id","email","google_subject").contains(column)) throw new IllegalArgumentException();
   return sql.sql("SELECT * FROM accounts WHERE "+column+" = :v").param("v",value)
    .query((r,n)->new Account(r.getString("id"),r.getString("email"),r.getString("display_name"),r.getString("password_hash"),r.getString("google_subject"))).optional();
 }
 Account create(String email,String name,String hash,String subject) {
   String id=UUID.randomUUID().toString();
   sql.sql("INSERT INTO accounts(id,email,display_name,password_hash,google_subject,created_at) VALUES(:id,:email,:name,:hash,:sub,:at)")
    .param("id",id).param("email",email).param("name",name).param("hash",hash).param("sub",subject).param("at",Instant.now().toString()).update();
   return find("id",id).orElseThrow();
 }
 Account current(Authentication auth) {
   if(auth==null || !auth.isAuthenticated()) throw new ResponseStatusException(UNAUTHORIZED,"Sign in to Attendly.");
   var account=auth.getPrincipal() instanceof OidcUser oidc ? find("google_subject",oidc.getSubject()) : find("id",auth.getName());
   return account.orElseThrow(()->new ResponseStatusException(UNAUTHORIZED,"Sign in to Attendly."));
 }
}

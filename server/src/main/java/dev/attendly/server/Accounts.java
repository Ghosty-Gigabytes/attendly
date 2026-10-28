package dev.attendly.server;
import java.time.Instant;
import java.util.*;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.security.core.Authentication;
import org.springframework.web.server.ResponseStatusException;
import static org.springframework.http.HttpStatus.*;
@Service
class Accounts {
 final JdbcClient sql;
 Accounts(JdbcClient sql){this.sql=sql;}
 record Account(String id,String name){Map<String,Object> publicView(){return Map.of("id",id,"name",name);}}
 Optional<Account> find(String id){return sql.sql("SELECT id,display_name FROM accounts WHERE id=:id").param("id",id)
   .query((r,n)->new Account(r.getString("id"),r.getString("display_name"))).optional();}
 Account create(String name){
   String id=UUID.randomUUID().toString();
   sql.sql("INSERT INTO accounts(id,display_name,created_at) VALUES(:id,:name,:at)")
     .param("id",id).param("name",name).param("at",Instant.now().toString()).update();
   return find(id).orElseThrow();
 }
 Account current(Authentication auth){
   if(auth==null||!auth.isAuthenticated())throw new ResponseStatusException(UNAUTHORIZED,"Sign in with IMS.");
   return find(auth.getName()).orElseThrow(()->new ResponseStatusException(UNAUTHORIZED,"Sign in with IMS."));
 }
}

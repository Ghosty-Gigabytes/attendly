package dev.attendly.server;
import java.util.*;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.core.Authentication;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
@RestController
class IdCardApi {
 final Accounts accounts;final ImsAccounts logins;final ImsService ims;final JdbcClient sql;final CredentialVault vault;
 IdCardApi(Accounts a,ImsAccounts l,ImsService i,JdbcClient s,CredentialVault v){accounts=a;logins=l;ims=i;sql=s;vault=v;}
 @GetMapping("/api/id-card") ResponseEntity<?> saved(Authentication auth) throws Exception {
   String owner=accounts.current(auth).id();
   var stored=sql.sql("SELECT cipher FROM id_card_snapshots WHERE owner_id=:o").param("o",owner).query(String.class).optional();
   if(stored.isEmpty())return privateResponse(Map.of("card",Map.of()));
   return privateResponse(Map.of("card",Json.read(vault.decrypt(owner,stored.get()))));
 }
 @PostMapping("/api/id-card/refresh") ResponseEntity<?> refresh(Authentication auth) throws Exception {
   String owner=accounts.current(auth).id();
   if(!ims.ready(owner))logins.refresh(owner);
   var data=ims.idCard(owner);String cipher=vault.encrypt(owner,Json.write(data));
   int changed=sql.sql("UPDATE id_card_snapshots SET cipher=:c,fetched_at=:at WHERE owner_id=:o")
     .param("c",cipher).param("at",data.get("fetchedAt")).param("o",owner).update();
   if(changed==0)sql.sql("INSERT INTO id_card_snapshots(owner_id,cipher,fetched_at) VALUES(:o,:c,:at)")
     .param("o",owner).param("c",cipher).param("at",data.get("fetchedAt")).update();
   sql.sql("UPDATE accounts SET display_name=:name WHERE id=:o").param("name",data.get("name")).param("o",owner).update();
   return privateResponse(Map.of("card",data));
 }
 static ResponseEntity<?> privateResponse(Object body){return ResponseEntity.ok().cacheControl(CacheControl.noStore()).header("Pragma","no-cache").body(body);}
}

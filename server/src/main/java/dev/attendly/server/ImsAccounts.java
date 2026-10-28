package dev.attendly.server;
import java.time.*;
import java.util.*;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.crypto.argon2.Argon2PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import static org.springframework.http.HttpStatus.*;

@Service
class ImsAccounts {
 final Accounts accounts;final ImsService ims;final JdbcClient sql;final CredentialVault vault;
 final Argon2PasswordEncoder hashes=new Argon2PasswordEncoder(16,32,1,19456,2);
 private final String dummy=hashes.encode(UUID.randomUUID().toString());
 record LoginResult(Accounts.Account account,boolean limited){}
 ImsAccounts(Accounts a,ImsService i,JdbcClient s,CredentialVault v){accounts=a;ims=i;sql=s;vault=v;}

 @Transactional
 LoginResult login(String flow,String challenge,String student,String password,String captcha,boolean remember) throws Exception {
   Map<String,Object> data;
   try{
     if(challenge==null||challenge.isBlank()){
       var generated=ims.challenge(flow);challenge=generated.get("id").toString();captcha=generated.get("answer").toString();
     }
     if(captcha==null||captcha.isBlank())throw new ResponseStatusException(BAD_REQUEST,"Enter the security number or refresh the image.");
     data=ims.verify(flow,challenge,student,password,captcha);
   }catch(ImsService.Unavailable unavailable){return fallback(student,password);}
   // Resolve ownership only after the report confirms the student identity.
   var existing=sql.sql("SELECT owner_id FROM ims_credentials WHERE student_id=:s").param("s",student).query(String.class).optional();
   if(existing.isEmpty())existing=sql.sql("SELECT owner_id FROM attendance_snapshots WHERE student_id=:s").param("s",student).query(String.class).optional();
   var account=existing.isPresent()?accounts.find(existing.get()).orElseThrow():accounts.create(student);
   String owner=account.id(), hash=hashes.encode(password), encrypted=remember?vault.encrypt(owner,password):null;
   String at=Instant.now().toString();
   int changed=sql.sql("UPDATE ims_credentials SET password_hash=:h,password_cipher=:c,verified_at=:at WHERE owner_id=:o")
     .param("h",hash).param("c",encrypted).param("at",at).param("o",owner).update();
   if(changed==0)sql.sql("INSERT INTO ims_credentials(owner_id,student_id,password_hash,password_cipher,verified_at) VALUES(:o,:s,:h,:c,:at)")
     .param("o",owner).param("s",student).param("h",hash).param("c",encrypted).param("at",at).update();
   ims.saveSnapshot(owner,student,data);
   var active=ims.flows.remove(flow);if(active!=null)ims.flows.put(owner,active);
   return new LoginResult(account,false);
 }
 LoginResult fallback(String student,String password){
   var saved=sql.sql("SELECT owner_id,password_hash,verified_at FROM ims_credentials WHERE student_id=:s").param("s",student)
     .query((r,n)->Map.of("owner",r.getString("owner_id"),"hash",r.getString("password_hash"),"at",r.getString("verified_at"))).optional();
   boolean matches=hashes.matches(password,saved.map(r->r.get("hash")).orElse(dummy));
   if(!matches||saved.isEmpty()||Instant.parse(saved.get().get("at")).isBefore(Instant.now().minus(Duration.ofDays(7))))
     throw new ResponseStatusException(SERVICE_UNAVAILABLE,"IMS is unavailable. Sign-in could not be verified; try again later.");
   return new LoginResult(accounts.find(saved.get().get("owner")).orElseThrow(),true);
 }
 boolean remembers(String owner){return sql.sql("SELECT COUNT(*) FROM ims_credentials WHERE owner_id=:o AND password_cipher IS NOT NULL").param("o",owner).query(Integer.class).single()>0;}
 void forget(String owner){sql.sql("UPDATE ims_credentials SET password_cipher=NULL WHERE owner_id=:o").param("o",owner).update();ims.flows.remove(owner);}
 Map<String,Object> refresh(String owner) throws Exception {
   if(ims.ready(owner))return ims.fetch(owner);
   var row=sql.sql("SELECT student_id,password_cipher FROM ims_credentials WHERE owner_id=:o AND password_cipher IS NOT NULL").param("o",owner)
     .query((r,n)->Map.of("student",r.getString("student_id"),"cipher",r.getString("password_cipher"))).optional();
   if(row.isEmpty())throw new ResponseStatusException(CONFLICT,"Sign in with IMS again to refresh. Saved attendance is still available.");
   // A new flow cannot disrupt a foreground session until verification succeeds.
   String flow=UUID.randomUUID().toString();
   try{
     var challenge=ims.challenge(flow);
     String answer=challenge.get("answer").toString();
     if(answer.isBlank())throw new ResponseStatusException(CONFLICT,"Sign in again to enter the security number.");
     String password=vault.decrypt(owner,row.get().get("cipher"));
     var data=ims.verify(flow,challenge.get("id").toString(),row.get().get("student"),password,answer);
     ims.saveSnapshot(owner,row.get().get("student"),data);
     sql.sql("UPDATE ims_credentials SET verified_at=:at WHERE owner_id=:o").param("at",Instant.now().toString()).param("o",owner).update();
     var active=ims.flows.remove(flow);if(active!=null)ims.flows.put(owner,active);
     return data;
   }catch(ResponseStatusException rejected){
     // Do not keep submitting credentials after an explicit IMS login rejection.
     if(rejected.getStatusCode().value()==400)forget(owner);
     throw rejected;
   }finally{ims.flows.remove(flow);}
 }
}

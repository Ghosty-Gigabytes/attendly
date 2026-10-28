package dev.attendly.server;
import java.util.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import static org.springframework.http.HttpStatus.*;
@RestController
class RecordsApi {
 final JdbcClient sql; final Accounts accounts; final ImsService ims;
 RecordsApi(JdbcClient s,Accounts a,ImsService i){sql=s;accounts=a;ims=i;}
 record Mutation(@NotBlank @Size(max=160) String scope,@Pattern(regexp="personal|timetable|plan") String kind,
   @NotBlank @Size(max=200) String id,@Min(0) long baseVersion,@NotNull UUID mutationId,boolean deleted,@NotNull Map<String,Object> payload) {}
 @GetMapping("/api/state") Map<String,Object> state(Authentication auth) {
   String owner=accounts.current(auth).id();
   var snapshot=sql.sql("SELECT scope,payload FROM attendance_snapshots WHERE owner_id=:o").param("o",owner)
     .query((r,n)->Map.of("scope",r.getString("scope"),"official",Json.read(r.getString("payload")))).optional();
   if(snapshot.isEmpty()) return Map.of("scope","","official",Map.of(),"records",List.of(),"imsSessionReady",ims.ready(owner));
   String scope=(String)snapshot.get().get("scope");
   var records=sql.sql("SELECT * FROM user_records WHERE owner_id=:o AND scope=:s").param("o",owner).param("s",scope).query((r,n)->Map.of(
     "kind",r.getString("kind"),"id",r.getString("record_id"),"version",r.getLong("revision"),"deleted",r.getBoolean("deleted"),"payload",Json.read(r.getString("payload")))).list();
   return Map.of("scope",scope,"official",snapshot.get().get("official"),"records",records,"imsSessionReady",ims.ready(owner));
 }
 @PostMapping("/api/records") @Transactional Map<String,Object> mutate(Authentication auth,@Valid @RequestBody Mutation body) throws Exception {
   if(body.kind()==null) throw new ResponseStatusException(BAD_REQUEST,"Choose a record type.");
   String owner=accounts.current(auth).id(), payload=Json.write(body.payload());
   if(payload.length()>250000 || !body.id().equals(body.payload().getOrDefault("id",body.id()))) throw new ResponseStatusException(BAD_REQUEST,"Invalid record.");
   // The row lock serializes revisions and duplicate requests for this owner.
   sql.sql("SELECT id FROM accounts WHERE id=:o FOR UPDATE").param("o",owner).query(String.class).single();
   String fingerprint=HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(Json.write(body).getBytes(StandardCharsets.UTF_8)));
   var replay=sql.sql("SELECT fingerprint,response FROM mutations WHERE owner_id=:o AND mutation_id=:m").param("o",owner).param("m",body.mutationId().toString()).query((r,n)->Map.of("fingerprint",r.getString(1),"response",r.getString(2))).optional();
   if(replay.isPresent()) {
     if(!fingerprint.equals(replay.get().get("fingerprint"))) throw new ResponseStatusException(CONFLICT,"A different change used the same request ID.");
     return Json.read(replay.get().get("response"));
   }
   var scope=sql.sql("SELECT scope FROM attendance_snapshots WHERE owner_id=:o").param("o",owner).query(String.class).optional();
   if(scope.isEmpty() || !scope.get().equals(body.scope())) throw new ResponseStatusException(CONFLICT,"Refresh this semester before syncing changes.");
   var current=sql.sql("SELECT revision FROM user_records WHERE owner_id=:o AND scope=:s AND kind=:k AND record_id=:id")
     .param("o",owner).param("s",body.scope()).param("k",body.kind()).param("id",body.id()).query(Long.class).optional();
   if(current.orElse(0L)!=body.baseVersion()) throw new ResponseStatusException(CONFLICT,"This record changed on another device. Review both versions before syncing.");
   long version=body.baseVersion()+1;
   if(current.isPresent()) sql.sql("UPDATE user_records SET revision=:v,deleted=:d,payload=:p WHERE owner_id=:o AND scope=:s AND kind=:k AND record_id=:id")
     .param("v",version).param("d",body.deleted()).param("p",payload).param("o",owner).param("s",body.scope()).param("k",body.kind()).param("id",body.id()).update();
   else sql.sql("INSERT INTO user_records(owner_id,scope,kind,record_id,revision,deleted,payload) VALUES(:o,:s,:k,:id,:v,:d,:p)")
     .param("o",owner).param("s",body.scope()).param("k",body.kind()).param("id",body.id()).param("v",version).param("d",body.deleted()).param("p",payload).update();
   var response=Map.<String,Object>of("kind",body.kind(),"id",body.id(),"version",version,"deleted",body.deleted(),"payload",body.payload());
   sql.sql("INSERT INTO mutations(owner_id,mutation_id,fingerprint,response) VALUES(:o,:m,:f,:r)").param("o",owner).param("m",body.mutationId().toString()).param("f",fingerprint).param("r",Json.write(response)).update();
   return response;
 }
}

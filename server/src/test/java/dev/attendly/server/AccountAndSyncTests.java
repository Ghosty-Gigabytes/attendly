package dev.attendly.server;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.http.MediaType;
import java.util.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
@SpringBootTest(properties={"IMS_CREDENTIAL_KEY=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=","attendly.background-refresh=false","spring.datasource.url=jdbc:h2:mem:attendlytest;MODE=PostgreSQL;DB_CLOSE_DELAY=-1;DATABASE_TO_LOWER=TRUE","spring.datasource.username=sa","spring.datasource.password=","server.servlet.session.cookie.secure=false"})
@AutoConfigureMockMvc
class AccountAndSyncTests {
 @org.springframework.test.context.bean.override.mockito.MockitoSpyBean ImsService ims;
 @Autowired CredentialVault vault;
 @Autowired ImsAccounts imsAccounts;
 @Autowired ImsSignInApi signins;
 @Test void refreshJobCanUseAProxiedAccountService(){
   Assertions.assertDoesNotThrow(()->new AttendanceRefreshJob(imsAccounts,sql,true).refresh());
 }
 @Autowired MockMvc mvc;@Autowired JdbcClient sql;@Autowired Accounts accounts;
 @BeforeEach void clean(){signins.limits.clear();sql.sql("DELETE FROM id_card_snapshots").update();sql.sql("DELETE FROM ims_credentials").update();sql.sql("DELETE FROM mutations").update();sql.sql("DELETE FROM user_records").update();sql.sql("DELETE FROM attendance_snapshots").update();sql.sql("DELETE FROM accounts").update();}
 @Test void removedAuthenticationRoutesCannotBeUsed() throws Exception {
   for(String path:List.of("/api/auth/login","/api/auth/signup","/oauth2/authorization/google"))
     mvc.perform(post(path).with(user("owner")).with(csrf()).contentType(MediaType.APPLICATION_JSON).content("{}")).andExpect(status().isNotFound());
   mvc.perform(get("/api/auth/me")).andExpect(status().isUnauthorized());
   mvc.perform(get("/api/state").with(user("nonexistent"))).andExpect(status().isUnauthorized());
 }
 @Test void browserCsrfEndpointCanAuthenticateAnImsRequest() throws Exception {
   acceptIms();
   var challenge=mvc.perform(get("/api/auth/csrf")).andExpect(status().isOk()).andReturn();
   var token=Json.read(challenge.getResponse().getContentAsString()).get("token");
   var result=mvc.perform(post("/api/auth/ims/login").session((MockHttpSession)challenge.getRequest().getSession())
     .header("X-CSRF-TOKEN",token).contentType(MediaType.APPLICATION_JSON).content(imsBody("ims-password",true)))
     .andExpect(status().isOk()).andReturn();
   mvc.perform(post("/api/auth/logout").session((MockHttpSession)result.getRequest().getSession()).with(csrf())).andExpect(status().isNoContent());
 }
 @Test void recordsAreIsolatedVersionedAndIdempotent() throws Exception {
   var one=accounts.create("One");var two=accounts.create("Two");
   for(var a:List.of(one,two))sql.sql("INSERT INTO attendance_snapshots(owner_id,student_id,scope,payload,fetched_at) VALUES(:o,:s,'scope','{}','now')").param("o",a.id()).param("s",a.id()).update();
   String mutation=UUID.randomUUID().toString();
   var body=new RecordsApi.Mutation("scope","personal","log",0,UUID.fromString(mutation),false,Map.of("id","log","weight",1));
   String json=Json.write(body);
   mvc.perform(post("/api/records").with(user(one.id())).with(csrf()).contentType(MediaType.APPLICATION_JSON).content(json)).andExpect(status().isOk()).andExpect(jsonPath("$.version").value(1));
   mvc.perform(post("/api/records").with(user(one.id())).with(csrf()).contentType(MediaType.APPLICATION_JSON).content(json)).andExpect(status().isOk()).andExpect(jsonPath("$.version").value(1));
   mvc.perform(get("/api/state").with(user(two.id()))).andExpect(jsonPath("$.records.length()").value(0));
   var stale=new RecordsApi.Mutation("scope","personal","log",0,UUID.randomUUID(),true,Map.of("id","log"));
   mvc.perform(post("/api/records").with(user(one.id())).with(csrf()).contentType(MediaType.APPLICATION_JSON).content(Json.write(stale))).andExpect(status().isConflict());
   var deletion=new RecordsApi.Mutation("scope","personal","log",1,UUID.randomUUID(),true,Map.of("id","log"));
   mvc.perform(post("/api/records").with(user(one.id())).with(csrf()).contentType(MediaType.APPLICATION_JSON).content(Json.write(deletion))).andExpect(status().isOk()).andExpect(jsonPath("$.version").value(2));
   mvc.perform(get("/api/state").with(user(one.id()))).andExpect(jsonPath("$.records[0].deleted").value(true));
 }
 String imsBody(String password,boolean remember){return Json.write(Map.of("studentId","TEST001","password",password,"challenge","challenge","captcha","12345","remember",remember));}
 void acceptIms() throws Exception {
   org.mockito.Mockito.doReturn(Map.of("semester","scope","account","TEST001","subjects",List.of(),"officialDays",List.of()))
     .when(ims).verify(org.mockito.ArgumentMatchers.anyString(),org.mockito.ArgumentMatchers.anyString(),org.mockito.ArgumentMatchers.anyString(),org.mockito.ArgumentMatchers.anyString(),org.mockito.ArgumentMatchers.anyString());
 }
 @Test void imsCreatesOneAccountAndStoresHashAndOwnerBoundCipher() throws Exception {
   acceptIms();
   var result=mvc.perform(post("/api/auth/ims/login").with(csrf()).contentType(MediaType.APPLICATION_JSON).content(imsBody("university-password",true)))
     .andExpect(status().isOk()).andExpect(jsonPath("$.studentId").value("TEST001")).andExpect(jsonPath("$.limited").value(false)).andReturn();
   String owner=Json.read(result.getResponse().getContentAsString()).get("id").toString();
   var row=sql.sql("SELECT password_hash,password_cipher FROM ims_credentials WHERE owner_id=:o").param("o",owner).query((r,n)->Map.of("hash",r.getString(1),"cipher",r.getString(2))).single();
   Assertions.assertTrue(row.get("hash").startsWith("$argon2id$"));
   Assertions.assertFalse(row.get("cipher").contains("university-password"));
   Assertions.assertEquals("university-password",vault.decrypt(owner,row.get("cipher")));
   Assertions.assertThrows(Exception.class,()->vault.decrypt("other-owner",row.get("cipher")));
   mvc.perform(post("/api/auth/ims/login").with(csrf()).contentType(MediaType.APPLICATION_JSON).content(imsBody("new-password",false))).andExpect(status().isOk()).andExpect(jsonPath("$.id").value(owner));
   Assertions.assertEquals(1,sql.sql("SELECT COUNT(*) FROM accounts").query(Integer.class).single());
   Assertions.assertEquals(0,sql.sql("SELECT COUNT(*) FROM ims_credentials WHERE password_cipher IS NOT NULL").query(Integer.class).single());
 }
 @Test void outageFallbackIsReadOnlyAndNeverUsedForRejectedCredentials() throws Exception {
   acceptIms();
   mvc.perform(post("/api/auth/ims/login").with(csrf()).contentType(MediaType.APPLICATION_JSON).content(imsBody("university-password",true))).andExpect(status().isOk());
   org.mockito.Mockito.doThrow(new ImsService.Unavailable()).when(ims).verify(org.mockito.ArgumentMatchers.anyString(),org.mockito.ArgumentMatchers.anyString(),org.mockito.ArgumentMatchers.anyString(),org.mockito.ArgumentMatchers.anyString(),org.mockito.ArgumentMatchers.anyString());
   var result=mvc.perform(post("/api/auth/ims/login").with(csrf()).contentType(MediaType.APPLICATION_JSON).content(imsBody("university-password",true))).andExpect(status().isOk()).andExpect(jsonPath("$.limited").value(true)).andReturn();
   var session=(MockHttpSession)result.getRequest().getSession();
   mvc.perform(get("/api/state").session(session)).andExpect(status().isOk());
   mvc.perform(post("/api/records").session(session).with(csrf()).contentType(MediaType.APPLICATION_JSON).content("{}")).andExpect(status().isForbidden());
   mvc.perform(post("/api/auth/ims/login").with(csrf()).contentType(MediaType.APPLICATION_JSON).content(imsBody("incorrect-password",true))).andExpect(status().isServiceUnavailable());
   sql.sql("UPDATE ims_credentials SET verified_at=:at").param("at",java.time.Instant.now().minus(java.time.Duration.ofDays(8)).toString()).update();
   mvc.perform(post("/api/auth/ims/login").with(csrf()).contentType(MediaType.APPLICATION_JSON).content(imsBody("university-password",true))).andExpect(status().isServiceUnavailable());
   org.mockito.Mockito.doThrow(new org.springframework.web.server.ResponseStatusException(org.springframework.http.HttpStatus.BAD_REQUEST,"IMS rejected the login"))
     .when(ims).verify(org.mockito.ArgumentMatchers.anyString(),org.mockito.ArgumentMatchers.anyString(),org.mockito.ArgumentMatchers.anyString(),org.mockito.ArgumentMatchers.anyString(),org.mockito.ArgumentMatchers.anyString());
   mvc.perform(post("/api/auth/ims/login").with(csrf()).contentType(MediaType.APPLICATION_JSON).content(imsBody("university-password",true))).andExpect(status().isBadRequest());
 }
 @Test void failedImsVerificationDoesNotCreateAnAccount() throws Exception {
   org.mockito.Mockito.doThrow(new org.springframework.web.server.ResponseStatusException(org.springframework.http.HttpStatus.BAD_REQUEST,"IMS rejected the login"))
     .when(ims).verify(org.mockito.ArgumentMatchers.anyString(),org.mockito.ArgumentMatchers.anyString(),org.mockito.ArgumentMatchers.anyString(),org.mockito.ArgumentMatchers.anyString(),org.mockito.ArgumentMatchers.anyString());
   mvc.perform(post("/api/auth/ims/login").with(csrf()).contentType(MediaType.APPLICATION_JSON).content(imsBody("wrong",true))).andExpect(status().isBadRequest());
   Assertions.assertEquals(0,sql.sql("SELECT COUNT(*) FROM accounts").query(Integer.class).single());
 }
 @Test void idCardsAreEncryptedAndOnlyVisibleToTheirOwner() throws Exception {
   var one=accounts.create("One");var two=accounts.create("Two");
   org.mockito.Mockito.doReturn(true).when(ims).ready(one.id());
   var card=Map.<String,Object>of("name","TEST STUDENT","rollNumber","TEST001","address","PRIVATE TEST ADDRESS","fetchedAt",java.time.Instant.now().toString());
   org.mockito.Mockito.doReturn(card).when(ims).idCard(one.id());
   mvc.perform(post("/api/id-card/refresh").with(user(one.id())).with(csrf())).andExpect(status().isOk()).andExpect(header().string("Cache-Control","no-store"));
   String stored=sql.sql("SELECT cipher FROM id_card_snapshots WHERE owner_id=:o").param("o",one.id()).query(String.class).single();
   Assertions.assertFalse(stored.contains("PRIVATE TEST ADDRESS"));
   mvc.perform(get("/api/id-card").with(user(one.id()))).andExpect(jsonPath("$.card.rollNumber").value("TEST001"));
   mvc.perform(get("/api/id-card").with(user(two.id()))).andExpect(jsonPath("$.card").isEmpty());
   mvc.perform(get("/api/id-card")).andExpect(status().isUnauthorized());
   var limited=new MockHttpSession();limited.setAttribute("limited",true);
   mvc.perform(post("/api/id-card/refresh").with(user(one.id())).session(limited).with(csrf())).andExpect(status().isForbidden());
 }
}

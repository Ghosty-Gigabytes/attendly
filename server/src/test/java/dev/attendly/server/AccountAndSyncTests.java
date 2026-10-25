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
@SpringBootTest(properties={"spring.datasource.url=jdbc:h2:mem:attendlytest;MODE=PostgreSQL;DB_CLOSE_DELAY=-1;DATABASE_TO_LOWER=TRUE","spring.datasource.username=sa","spring.datasource.password=","server.servlet.session.cookie.secure=false"})
@AutoConfigureMockMvc
class AccountAndSyncTests {
 @Autowired MockMvc mvc;@Autowired JdbcClient sql;@Autowired Accounts accounts;
 @BeforeEach void clean(){sql.sql("DELETE FROM mutations").update();sql.sql("DELETE FROM user_records").update();sql.sql("DELETE FROM attendance_snapshots").update();sql.sql("DELETE FROM accounts").update();}
 @Test void signupSessionPasswordAndLogout() throws Exception {
   mvc.perform(get("/api/auth/me")).andExpect(status().isUnauthorized());
   mvc.perform(post("/api/auth/signup").contentType(MediaType.APPLICATION_JSON).content("{}")).andExpect(status().isForbidden());
   var result=mvc.perform(post("/api/auth/signup").with(csrf()).contentType(MediaType.APPLICATION_JSON).content("{\"email\":\"student@example.test\",\"password\":\"password123\",\"name\":\"Student\"}"))
     .andExpect(status().isOk()).andExpect(jsonPath("$.email").value("student@example.test")).andExpect(jsonPath("$.hash").doesNotExist()).andReturn();
   var session=(MockHttpSession)result.getRequest().getSession();
   mvc.perform(get("/api/auth/me").session(session)).andExpect(status().isOk());
   Assertions.assertTrue(accounts.find("email","student@example.test").orElseThrow().hash().startsWith("$2"));
   mvc.perform(post("/api/auth/logout").session(session).with(csrf())).andExpect(status().isNoContent());
   mvc.perform(post("/api/auth/login").with(csrf()).contentType(MediaType.APPLICATION_JSON).content("{\"email\":\"student@example.test\",\"password\":\"wrong-pass\"}")).andExpect(status().isUnauthorized());
   mvc.perform(post("/api/auth/login").with(csrf()).contentType(MediaType.APPLICATION_JSON).content("{\"email\":\"student@example.test\",\"password\":\"password123\"}")).andExpect(status().isOk());
 }
 @Test void googleIsDisabledWithoutCredentialsAndUnknownAccountsAreRejected() throws Exception {
   mvc.perform(get("/api/config")).andExpect(status().isOk()).andExpect(jsonPath("$.googleEnabled").value(false));
   mvc.perform(get("/api/state").with(user("nonexistent"))).andExpect(status().isUnauthorized());
 }
 @Test void browserCsrfEndpointCanAuthenticateAnAjaxRequest() throws Exception {
   var challenge=mvc.perform(get("/api/auth/csrf")).andExpect(status().isOk()).andReturn();
   var token=Json.read(challenge.getResponse().getContentAsString()).get("token");
   mvc.perform(post("/api/auth/signup").session((MockHttpSession)challenge.getRequest().getSession())
     .header("X-CSRF-TOKEN",token).contentType(MediaType.APPLICATION_JSON)
     .content("{\"email\":\"browser@example.test\",\"password\":\"password123\",\"name\":\"Browser\"}"))
     .andExpect(status().isOk());
 }
 @Test void recordsAreIsolatedVersionedAndIdempotent() throws Exception {
   var one=accounts.create("one@example.test","One",null,null);var two=accounts.create("two@example.test","Two",null,null);
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
}

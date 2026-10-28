package dev.attendly.server;
import java.net.*;
import java.net.http.*;
import java.nio.charset.StandardCharsets;
import java.time.*;
import java.time.format.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.regex.*;
import java.util.stream.*;
import org.jsoup.*;
import org.jsoup.nodes.*;
import org.springframework.stereotype.Service;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.web.server.ResponseStatusException;
import static org.springframework.http.HttpStatus.*;
@Service
class ImsService {
 static final URI ROOT=URI.create("https://www.imsnsit.org/imsnsit/");
 static class Unavailable extends RuntimeException { Unavailable(){super("IMS is temporarily unavailable.");} }
 final Map<String,Flow> flows=new ConcurrentHashMap<>(); final JdbcClient sql;
 final CaptchaOcr ocr;
 ImsService(JdbcClient sql,CaptchaOcr ocr){this.sql=sql;this.ocr=ocr;}
 static class Flow {
   final String challenge=UUID.randomUUID().toString(); final Instant started=Instant.now();
   final HttpClient client=HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(20)).cookieHandler(new CookieManager(null,CookiePolicy.ACCEPT_ORIGINAL_SERVER)).followRedirects(HttpClient.Redirect.NEVER).build();
   String token,student; URI activity,logo;
 }
 boolean ready(String owner){var f=flows.get(owner);return f!=null&&f.activity!=null&&f.started.isAfter(Instant.now().minus(Duration.ofMinutes(30)));}
 static void allow(URI uri){if(!"https".equals(uri.getScheme())||!Set.of("imsnsit.org","www.imsnsit.org").contains(uri.getHost())||(uri.getPort()!=-1&&uri.getPort()!=443)||!uri.getPath().startsWith("/imsnsit"))throw new ResponseStatusException(BAD_GATEWAY,"IMS returned an unexpected destination.");}
 static HttpRequest.Builder portalRequest(URI uri){
   // IMS uses these headers even on GET requests. Match the working Android
   // adapter: omitting them can return a placeholder instead of the login form.
   return HttpRequest.newBuilder(uri).timeout(Duration.ofSeconds(35))
     .header("User-Agent","Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.119 Safari/537.36")
     .header("Accept","text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8")
     .header("Accept-Language","en-US,en;q=0.5")
     .header("Upgrade-Insecure-Requests","1")
     .header("Referer",ROOT.resolve("student_login.php").toString())
     .header("Origin","https://www.imsnsit.org")
     .header("Content-Type","application/x-www-form-urlencoded");
 }
 static HttpResponse<byte[]> request(Flow f,URI uri,Map<String,String> fields) throws Exception {
   for(int i=0;i<6;i++){
     allow(uri);
     var b=portalRequest(uri);
     if(fields==null)b.GET();else b.POST(HttpRequest.BodyPublishers.ofString(encode(fields)));
     HttpResponse<byte[]> response;
     try{response=f.client.send(b.build(),HttpResponse.BodyHandlers.ofByteArray());}
     catch(java.net.ConnectException|java.net.http.HttpTimeoutException e){throw new Unavailable();}
     if(response.body().length>4000000)throw new ResponseStatusException(BAD_GATEWAY,"IMS returned a report that is too large.");
     if(response.statusCode()>=300&&response.statusCode()<400){uri=uri.resolve(response.headers().firstValue("location").orElseThrow());if(response.statusCode()!=307&&response.statusCode()!=308)fields=null;continue;}
     if(Set.of(502,503,504).contains(response.statusCode()))throw new Unavailable();
     if(response.statusCode()!=200)throw new ResponseStatusException(BAD_GATEWAY,"IMS could not complete the request. Try again later.");
     return response;
   }
   throw new ResponseStatusException(BAD_GATEWAY,"Too many IMS redirects.");
 }
 static String encode(Map<String,String> fields){return fields.entrySet().stream().map(e->URLEncoder.encode(e.getKey(),StandardCharsets.UTF_8)+"="+URLEncoder.encode(e.getValue(),StandardCharsets.UTF_8)).collect(Collectors.joining("&"));}
 static Document doc(HttpResponse<byte[]> response){return Jsoup.parse(new String(response.body(),StandardCharsets.UTF_8),response.uri().toString());}
 Map<String,Object> challenge(String owner) throws Exception {
   flows.entrySet().removeIf(e->e.getValue().started.isBefore(Instant.now().minus(Duration.ofMinutes(30))));
   Flow f=new Flow(); request(f,URI.create("https://www.imsnsit.org/imsnsit"),null);
   var page=doc(request(f,ROOT.resolve("student_login110.php"),null));
   var token=page.selectFirst("#HRAND_NUM");var image=page.selectFirst("#captchaimg[src]");
   if(token==null||image==null)throw new ResponseStatusException(BAD_GATEWAY,"IMS did not return the login challenge.");
   f.token=token.attr("value");var response=request(f,URI.create(image.absUrl("src")),null);
   byte[] bytes=response.body();String mime=response.headers().firstValue("content-type").orElse("").split(";")[0];
   if(bytes.length<8||!Set.of("image/png","image/jpeg","image/gif").contains(mime))throw new ResponseStatusException(BAD_GATEWAY,"IMS returned an invalid CAPTCHA image.");
   String answer=ocr.recognize(bytes);
   flows.put(owner,f);return Map.of("id",f.challenge,"image","data:"+mime+";base64,"+Base64.getEncoder().encodeToString(bytes),"answer",answer);
 }
 Map<String,Object> verify(String owner,String challenge,String student,String password,String captcha) throws Exception {
   var f=flows.get(owner);
   if(f==null||!f.challenge.equals(challenge)||f.started.isBefore(Instant.now().minusSeconds(300)))throw new ResponseStatusException(BAD_REQUEST,"Refresh the expired CAPTCHA.");
   synchronized(f){
     if(f.activity!=null)throw new ResponseStatusException(BAD_REQUEST,"Refresh the CAPTCHA before signing in again.");
     var fields=new LinkedHashMap<String,String>();fields.put("uid",student);fields.put("pwd",password);fields.put("HRAND_NUM",f.token);
     fields.put("fy","2024-25");fields.put("comp","NETAJI SUBHAS UNIVERSITY OF TECHNOLOGY");fields.put("cap",captcha);fields.put("logintype","student");
     var page=doc(request(f,ROOT.resolve("student_login.php"),fields));
     if(page.selectFirst("[name=HRAND_NUM],#HRAND_NUM")!=null)throw new ResponseStatusException(BAD_REQUEST,"IMS rejected the login. Refresh the CAPTCHA and check your credentials.");
     f.activity=link(page,"My Activities");f.student=student;
     var logo=page.selectFirst("img[src*=logo],img[width=100][height=100][src]");
     if(logo!=null)f.logo=URI.create(logo.absUrl("src"));
     try{return readSnapshot(f);}catch(Exception e){f.activity=null;throw e;}
   }
 }
 static URI link(Document page,String text){return page.select("a[href]").stream().filter(a->a.text().replace(".","").trim().equalsIgnoreCase(text.replace(".",""))).map(a->URI.create(a.absUrl("href"))).findFirst().orElseThrow(()->new ResponseStatusException(BAD_GATEWAY,"IMS navigation changed. Reconnect or retry later."));}
 static String selected(Document doc,String selector){var el=doc.selectFirst(selector+" option[selected]");return el==null?"":el.val();}
 Map<String,Object> idCard(String owner) throws Exception {
   if(!ready(owner))throw new ResponseStatusException(CONFLICT,"Sign in with IMS again to load your ID card.");
   var f=flows.get(owner);
   synchronized(f){
     var menu=doc(request(f,f.activity,null));
     URI target=IdCardParser.link(menu,"ID Card Details","ID Card Detail");
     if(target==null){
       URI personal=IdCardParser.link(menu,"Personal Info","Personal Information");
       if(personal!=null)target=IdCardParser.link(doc(request(f,personal,null)),"ID Card Details","ID Card Detail");
     }
     if(target==null)throw new ResponseStatusException(BAD_GATEWAY,"Could not find ID Card Details under Personal Info in IMS.");
     var parsed=IdCardParser.parse(doc(request(f,target,null)),f.student);
     var data=new LinkedHashMap<>(parsed.data());
     data.put("photo",cardImage(f,parsed.photo()));data.put("signature",cardImage(f,parsed.signature()));
     data.put("logo",cardImage(f,f.logo==null?ROOT.resolve("images/mlogo.png"):f.logo));
     return data;
   }
 }
 static String cardImage(Flow f,URI uri){
   if(uri==null)return null;
   try{
     byte[] bytes=request(f,uri,null).body();
     if(bytes.length<12||bytes.length>1_000_000)return null;
     boolean valid=(bytes[0]==(byte)0xff&&bytes[1]==(byte)0xd8&&bytes[2]==(byte)0xff)
       ||(bytes[0]==(byte)0x89&&bytes[1]==0x50&&bytes[2]==0x4e&&bytes[3]==0x47)
       ||(bytes[0]==0x47&&bytes[1]==0x49&&bytes[2]==0x46)
       ||(new String(bytes,0,4,StandardCharsets.US_ASCII).equals("RIFF")&&new String(bytes,8,4,StandardCharsets.US_ASCII).equals("WEBP"));
     return valid?Base64.getEncoder().encodeToString(bytes):null;
   }catch(Exception unavailable){return null;}
 }
 Map<String,Object> fetch(String owner) throws Exception {
   if(!ready(owner))throw new ResponseStatusException(CONFLICT,"Reconnect IMS to refresh. Your saved attendance is still available.");
   var f=flows.get(owner);
   synchronized(f){
     var data=readSnapshot(f);saveSnapshot(owner,f.student,data);return data;
   }
 }
 Map<String,Object> readSnapshot(Flow f) throws Exception {
     var activity=doc(request(f,f.activity,null));String year=selected(activity,"select[name=year]");
     if(!year.matches("\\d{4}-\\d{2,4}"))throw new ResponseStatusException(BAD_GATEWAY,"Could not verify the current academic year.");
     String semester="";Map<String,String> names=new HashMap<>();
     try{var courses=doc(request(f,link(activity,"Current Sem Courses Registered."),null));
       var match=Pattern.compile("Semester\\s*:?\\s*(\\d+)",Pattern.CASE_INSENSITIVE).matcher(courses.text());if(match.find())semester=match.group(1);
       for(var row:courses.select("tr")){var cells=row.children();for(int i=0;i<cells.size()-1;i++)if(cells.get(i).text().trim().matches("[A-Z]{2,}[A-Z0-9]*\\d[A-Z0-9]*"))names.put(cells.get(i).text().trim(),cells.get(i+1).text().trim());}
     }catch(Exception ignored){/* Course metadata must not decide attendance column order. */}
     var formPage=doc(request(f,link(activity,"My Attendance"),null));
     var token=formPage.selectFirst("[name=enc_year]");if(token==null)throw new ResponseStatusException(BAD_GATEWAY,"IMS attendance form changed.");
     Element form=token.closest("form");Element container=form==null?formPage:form;
     var fields=new LinkedHashMap<String,String>();for(var el:container.select("input[name]"))if(!Set.of("submit","button").contains(el.attr("type")))fields.put(el.attr("name"),el.val());
     for(var el:container.select("select[name]")){var option=el.selectFirst("option[selected]");if(option!=null)fields.put(el.attr("name"),option.val());}
     if(semester.isBlank())semester=selected(formPage,"select[name=sem]");
     if(!semester.matches("[1-9][0-9]?"))throw new ResponseStatusException(BAD_GATEWAY,"Could not verify your semester.");
     fields.put("year",year);fields.put("sem",semester);fields.put("submit","Submit");
     URI action=form==null?URI.create(formPage.baseUri()):URI.create(form.absUrl("action").isBlank()?formPage.baseUri():form.absUrl("action"));
     var report=doc(request(f,action,fields));
     // A report has the verified student number. Never attach an unchecked identity.
     if(!Pattern.compile("(?<![A-Z0-9-])"+Pattern.quote(f.student.toUpperCase(Locale.ROOT))+"(?![A-Z0-9-])").matcher(report.text().toUpperCase(Locale.ROOT)).find())throw new ResponseStatusException(BAD_GATEWAY,"Could not verify the student identity in this report.");
     var parsed=parseReport(report,year,names);String scope=year+" · Semester "+semester;
     var data=new LinkedHashMap<String,Object>();data.put("subjects",parsed.get("subjects"));data.put("officialDays",parsed.get("officialDays"));
     data.put("sessions",List.of());data.put("timetable",List.of());data.put("scenarios",List.of());data.put("account",f.student);data.put("semester",scope);data.put("synced",Instant.now().toString());data.put("showPersonal",false);data.put("target",75);
     return data;
 }
 void saveSnapshot(String owner,String student,Map<String,Object> data){
     String scope=data.get("semester").toString();
     var currentStudent=sql.sql("SELECT student_id FROM attendance_snapshots WHERE owner_id=:o").param("o",owner).query(String.class).optional();
     if(currentStudent.isPresent()&&!currentStudent.get().equals(student))throw new ResponseStatusException(CONFLICT,"This Attendly account is already linked to a different student. Account switching is not enabled yet.");
     var other=sql.sql("SELECT owner_id FROM attendance_snapshots WHERE student_id=:s").param("s",student).query(String.class).optional();
     if(other.isPresent()&&!other.get().equals(owner))throw new ResponseStatusException(CONFLICT,"This IMS account is already connected to another Attendly account.");
     int changed=sql.sql("UPDATE attendance_snapshots SET student_id=:s,scope=:scope,payload=:p,fetched_at=:at WHERE owner_id=:o").param("s",student).param("scope",scope).param("p",Json.write(data)).param("at",Instant.now().toString()).param("o",owner).update();
     if(changed==0)sql.sql("INSERT INTO attendance_snapshots(owner_id,student_id,scope,payload,fetched_at) VALUES(:o,:s,:scope,:p,:at)").param("o",owner).param("s",student).param("scope",scope).param("p",Json.write(data)).param("at",Instant.now().toString()).update();
 }
 static Map<String,Object> parseReport(Document report,String year,Map<String,String> names){
   var totals=new LinkedHashMap<String,Map<String,Integer>>();var days=new LinkedHashMap<String,Object>();int start=Integer.parseInt(year.substring(0,4));
   for(var table:report.select("table")){
     var rows=table.select("tr").stream().filter(r->r.closest("table")==table).toList();List<String> codes=null;
     for(var row:rows){var cells=row.children();if(cells.isEmpty())continue;String label=cells.first().text().trim();String key=label.toLowerCase(Locale.ROOT).replaceAll("[^a-z]","");
       if(key.equals("days")||key.equals("date")){
         codes=cells.stream().skip(1).map(e->e.text().trim().toUpperCase(Locale.ROOT)).toList();
         if(codes.isEmpty()||codes.stream().anyMatch(String::isBlank)||new HashSet<>(codes).size()!=codes.size())throw new ResponseStatusException(BAD_GATEWAY,"IMS attendance headers are missing. Saved attendance has not changed.");
         for(String code:codes)totals.computeIfAbsent(code,k->new HashMap<>());continue;
       }
       if(codes==null||cells.size()!=codes.size()+1)continue;
       String countKey=key.equals("overallclass")||key.equals("overallclasses")?"t":key.equals("overallpresent")?"a":key.equals("overallabsent")?"absent":null;
       if(countKey!=null){for(int i=0;i<codes.size();i++){try{int value=Integer.parseInt(cells.get(i+1).text().trim());var existing=totals.get(codes.get(i)).putIfAbsent(countKey,value);if(existing!=null&&existing!=value)throw new NumberFormatException();}catch(NumberFormatException ex){throw new ResponseStatusException(BAD_GATEWAY,"IMS totals could not be verified.");}}continue;}
       if(label.matches("[A-Za-z]{3}-\\d{1,2}")){
         var monthDay=MonthDay.parse(label,DateTimeFormatter.ofPattern("MMM-d",Locale.ENGLISH));var date=monthDay.atYear(monthDay.getMonthValue()>=7?start:start+1).toString();
         for(int i=0;i<codes.size();i++){String raw=cells.get(i+1).text().trim();String k=codes.get(i)+":"+date;var value=Map.of("subject",codes.get(i),"date",date,"raw",raw);if(days.containsKey(k)&&!days.get(k).equals(value))throw new ResponseStatusException(BAD_GATEWAY,"IMS returned conflicting daily records.");days.put(k,value);}
       }
     }
   }
   var subjects=new ArrayList<Object>();int index=0;for(var e:totals.entrySet()){
     var t=e.getValue();if(!t.containsKey("a")||!t.containsKey("t")||t.get("a")<0||t.get("t")<t.get("a")||(t.containsKey("absent")&&t.get("a")+t.get("absent")!=t.get("t")))throw new ResponseStatusException(BAD_GATEWAY,"Verified IMS totals are missing. Saved attendance has not changed.");
     subjects.add(Map.of("code",e.getKey(),"name",names.getOrDefault(e.getKey(),e.getKey()),"official",Map.of("a",t.get("a"),"t",t.get("t")),"color",new long[]{0xFF4469E8L,0xFF179B89L,0xFF9B64D9L}[index++%3]));
   }
   if(subjects.isEmpty())throw new ResponseStatusException(BAD_GATEWAY,"IMS returned no attendance subjects.");
   return Map.of("subjects",subjects,"officialDays",new ArrayList<>(days.values()));
 }
}

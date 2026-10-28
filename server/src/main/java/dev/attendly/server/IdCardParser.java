package dev.attendly.server;
import java.net.URI;
import java.time.Instant;
import java.util.*;
import java.util.regex.Pattern;
import org.jsoup.nodes.*;
import org.springframework.web.server.ResponseStatusException;
import static org.springframework.http.HttpStatus.BAD_GATEWAY;
class IdCardParser {
 record Details(Map<String,Object> data,URI photo,URI signature){}
 static String key(String value){return value.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]","");}
 static URI link(Document page,String... labels){
   var keys=Arrays.stream(labels).map(IdCardParser::key).toList();
   return page.select("a[href]").stream().filter(a->keys.contains(key(a.text())))
     .filter(a->!a.attr("href").isBlank()&&!a.attr("href").equals("#")&&!a.attr("href").toLowerCase(Locale.ROOT).startsWith("javascript:"))
     .map(a->URI.create(a.absUrl("href"))).findFirst().orElse(null);
 }
 static Details parse(Document page,String student){
   Map<String,String> fields=new HashMap<>();List<String> address=new ArrayList<>();
   String roll="";Element photo=null,signature=null;boolean continuation=false;
   for(var row:page.select("tr")){
     var cells=row.children();if(cells.size()<2)continue;
     String label=key(cells.first().text()),value=cells.get(1).text().replaceFirst("^:\\s*","").trim();
     if(!label.isBlank())fields.put(label,value);
     for(var cell:cells){var match=Pattern.compile("ID\\s*No\\s*:\\s*([A-Za-z0-9-]+)",Pattern.CASE_INSENSITIVE).matcher(cell.text());if(match.find())roll=match.group(1);}
     if(Set.of("permanentaddress","communicationaddress").contains(label)){
       address.add(value);continuation=true;signature=cells.get(1).selectFirst("img[height=30][src]");
     }else if(continuation&&label.isEmpty()){if(!value.isEmpty())address.add(value);}else continuation=false;
     if(label.equals("fathersname"))for(var cell:cells.stream().skip(2).toList())if(photo==null)photo=cell.selectFirst("img[src]");
   }
   if(!roll.equalsIgnoreCase(student)||fields.getOrDefault("name","").isBlank()||fields.getOrDefault("program","").isBlank())
     throw new ResponseStatusException(BAD_GATEWAY,"Could not verify your ID card in IMS. Your saved card has not changed.");
   Map<String,Object> result=new LinkedHashMap<>();
   result.put("name",fields.get("name"));result.put("rollNumber",roll);result.put("course",fields.get("program"));
   result.put("parentName",fields.getOrDefault("fathersname",""));result.put("branch",fields.getOrDefault("department",""));
   result.put("mobile",fields.getOrDefault("phno","").replaceAll("(?i)\\s*\\([MR]\\)","").trim());
   result.put("address",String.join(", ",address));result.put("dob",fields.getOrDefault("dob",""));
   result.put("issueDate",fields.getOrDefault("dateofissue",""));result.put("bloodGroup",fields.getOrDefault("bloodgroup",""));
   result.put("email",fields.getOrDefault("email",""));result.put("fetchedAt",Instant.now().toString());
   return new Details(result,photo==null?null:URI.create(photo.absUrl("src")),signature==null?null:URI.create(signature.absUrl("src")));
 }
}

package dev.attendly.server;
import java.util.*;
import org.junit.jupiter.api.*;
import org.jsoup.Jsoup;
import org.springframework.web.server.ResponseStatusException;
class ImsReportTests {
 String report="<table><tr><td>Days</td><td>MA101</td></tr><tr><td>Jul-28</td><td>1+0</td></tr><tr><td>Jul-29</td><td>NT</td></tr><tr><td>Jul-30</td><td></td></tr><tr><td>Overall Class</td><td>2</td></tr><tr><td>Overall Present</td><td>1</td></tr><tr><td>Overall Absent</td><td>1</td></tr></table>";
 @Test void reportHeadersOwnColumnsAndUnknownCoursesDoNotCreatePhantomSubjects(){
   var result=ImsService.parseReport(Jsoup.parse(report),"2026-27",Map.of("MA101","Maths","EXTRA","No classes"));
   var subjects=(List<?>)result.get("subjects");Assertions.assertEquals(1,subjects.size());
   Assertions.assertEquals("Maths",((Map<?,?>)subjects.get(0)).get("name"));
   var days=(List<?>)result.get("officialDays");Assertions.assertEquals(3,days.size());
   Assertions.assertEquals("NT",((Map<?,?>)days.get(1)).get("raw"));
 }
 @Test void missingHeaderOrInconsistentTotalsCannotReplaceTheCache(){
   Assertions.assertThrows(ResponseStatusException.class,()->ImsService.parseReport(Jsoup.parse(report.replace("MA101","")),"2026-27",Map.of()));
   Assertions.assertThrows(ResponseStatusException.class,()->ImsService.parseReport(Jsoup.parse(report.replace("<td>Overall Present</td><td>1", "<td>Overall Present</td><td>4")),"2026-27",Map.of()));
 }
 @Test void portalRequestsCannotBeRedirectedToArbitraryHosts(){Assertions.assertThrows(ResponseStatusException.class,()->ImsService.allow(java.net.URI.create("https://example.com/imsnsit/")));}
}

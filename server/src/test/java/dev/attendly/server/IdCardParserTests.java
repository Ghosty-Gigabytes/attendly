package dev.attendly.server;
import org.junit.jupiter.api.Test;
import org.jsoup.Jsoup;
import org.springframework.web.server.ResponseStatusException;
import static org.junit.jupiter.api.Assertions.*;
class IdCardParserTests {
 String html="""
 <table><tr><td>Name</td><td>: TEST STUDENT</td><td>ID No: TEST001</td></tr>
 <tr><td>Father's Name</td><td>: TEST PARENT</td><td><img src='photo.php?opaque' width='100' height='100'></td></tr>
 <tr><td>Program</td><td>: B.Tech.</td></tr><tr><td>Department</td><td>: TEST DEPARTMENT</td></tr>
 <tr><td>Specialization</td><td>: DO NOT USE AS BRANCH</td></tr>
 <tr><td>Ph.No.</td><td>: 1234567890 (M)</td></tr><tr><td>Parent's Contact No</td><td>: 9999999999</td></tr>
 <tr><td>Permanent Address</td><td>: Test address<img src='signature.php' height='30'></td></tr>
 <tr><td>&nbsp;</td><td>Test city - 100001</td></tr></table>
 """;
 @Test void departmentStudentPhoneAddressAndImagesMatchTheAndroidContract(){
   var card=IdCardParser.parse(Jsoup.parse(html,"https://www.imsnsit.org/imsnsit/details.php"),"TEST001");
   assertEquals("TEST DEPARTMENT",card.data().get("branch"));assertEquals("1234567890",card.data().get("mobile"));
   assertEquals("Test address, Test city - 100001",card.data().get("address"));
   assertEquals("https://www.imsnsit.org/imsnsit/photo.php?opaque",card.photo().toString());
   assertEquals("https://www.imsnsit.org/imsnsit/signature.php",card.signature().toString());
 }
 @Test void anotherStudentsCardAndIncompletePagesAreRejected(){
   assertThrows(ResponseStatusException.class,()->IdCardParser.parse(Jsoup.parse(html),"OTHER001"));
   assertThrows(ResponseStatusException.class,()->IdCardParser.parse(Jsoup.parse("<p>Login expired</p>"),"TEST001"));
 }
 @Test void navigationLabelsHandlePunctuation(){
   var page=Jsoup.parse("<a href='personal.php'>Personal Info.</a>","https://www.imsnsit.org/imsnsit/menu.php");
   assertEquals("https://www.imsnsit.org/imsnsit/personal.php",IdCardParser.link(page,"Personal Info").toString());
 }
}

package dev.attendly.server;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
class CaptchaOcrTests {
 @Test void acceptsOnlyDigitsAfterRemovingWhitespace(){
   assertEquals("12345",CaptchaOcr.normalize("12 345\n"));
   assertEquals("",CaptchaOcr.normalize("12O45"));
   assertEquals("",CaptchaOcr.normalize(""));
 }
 @Test void unavailableRecognitionDoesNotPreventManualEntry(){
   var ocr=new CaptchaOcr();
   assertEquals("",ocr.recognize(new byte[0]));
   assertEquals("",ocr.recognize(new byte[512_001]));
 }
}

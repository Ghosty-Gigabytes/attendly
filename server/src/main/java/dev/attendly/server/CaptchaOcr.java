package dev.attendly.server;

import java.io.IOException;
import java.nio.file.*;
import java.util.concurrent.Semaphore;
import org.bytedeco.javacpp.BytePointer;
import org.bytedeco.leptonica.PIX;
import org.bytedeco.tesseract.TessBaseAPI;
import static org.bytedeco.leptonica.global.leptonica.*;
import org.springframework.stereotype.Service;

/** Local OCR only. Images, recognized answers and credentials are never logged. */
@Service
class CaptchaOcr {
 private final Semaphore slots=new Semaphore(2);
 private Path modelDirectory;

 private synchronized Path model() throws IOException {
   if(modelDirectory!=null)return modelDirectory;
   var directory=Files.createTempDirectory("attendly-ocr-");
   var destination=directory.resolve("mydigits.traineddata");
   try(var input=CaptchaOcr.class.getResourceAsStream("/ocr/mydigits.traineddata")){
     if(input==null)throw new IOException("OCR model unavailable");
     Files.copy(input,destination);
   }catch(IOException error){Files.deleteIfExists(destination);Files.deleteIfExists(directory);throw error;}
   directory.toFile().deleteOnExit();destination.toFile().deleteOnExit();
   modelDirectory=directory;return directory;
 }

 String recognize(byte[] bytes){
   if(bytes.length<8||bytes.length>512_000||!slots.tryAcquire())return "";
   try(var data=new BytePointer(bytes);var tess=new TessBaseAPI()){
     PIX image=pixReadMem(data,bytes.length);
     if(image==null||image.isNull())return "";
     try{
       if(pixGetWidth(image)>1024||pixGetHeight(image)>512)return "";
       if(tess.Init(model().toString(),"mydigits")!=0)return "";
       try{
         tess.SetPageSegMode(11); // Same sparse-text mode as Android/Python.
         tess.SetImage(image);
         try(BytePointer text=tess.GetUTF8Text()){
           return text==null||text.isNull()?"":normalize(text.getString());
         }
       }finally{tess.End();}
     }finally{pixDestroy(image);}
   }catch(Exception|LinkageError error){return "";}
   finally{slots.release();}
 }

 static String normalize(String text){
   String answer=text.replaceAll("\\s+","");
   return answer.matches("[0-9]{1,16}")?answer:"";
 }
}

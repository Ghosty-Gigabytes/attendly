package dev.attendly.server;
import java.nio.file.*;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.*;
import javax.crypto.Cipher;
import javax.crypto.spec.*;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Service;

@Service
class CredentialVault {
 private final byte[] key;
 CredentialVault(Environment env) throws Exception {
   String supplied=env.getProperty("IMS_CREDENTIAL_KEY","");
   if(!supplied.isBlank())key=Base64.getDecoder().decode(supplied);
   else if(Arrays.asList(env.getActiveProfiles()).contains("local")){
     Path file=Path.of(".local","ims-credential.key");
     Files.createDirectories(file.getParent());
     if(!Files.exists(file)){
       byte[] generated=new byte[32];new SecureRandom().nextBytes(generated);
       try{Files.write(file,generated,StandardOpenOption.CREATE_NEW);}catch(FileAlreadyExistsException ignored){}
     }
     key=Files.readAllBytes(file);
   }
   else throw new IllegalStateException("Set IMS_CREDENTIAL_KEY to a base64-encoded 32-byte key managed separately from the database.");
   if(key.length!=32)throw new IllegalStateException("IMS_CREDENTIAL_KEY must contain 32 bytes.");
 }
 String encrypt(String owner,String password) throws Exception {
   byte[] nonce=new byte[12];new SecureRandom().nextBytes(nonce);
   var cipher=Cipher.getInstance("AES/GCM/NoPadding");
   cipher.init(Cipher.ENCRYPT_MODE,new SecretKeySpec(key,"AES"),new GCMParameterSpec(128,nonce));
   cipher.updateAAD(owner.getBytes(StandardCharsets.UTF_8));
   byte[] data=cipher.doFinal(password.getBytes(StandardCharsets.UTF_8));
   return Base64.getEncoder().encodeToString(nonce)+":"+Base64.getEncoder().encodeToString(data);
 }
 String decrypt(String owner,String stored) throws Exception {
   var parts=stored.split(":",2);var cipher=Cipher.getInstance("AES/GCM/NoPadding");
   cipher.init(Cipher.DECRYPT_MODE,new SecretKeySpec(key,"AES"),new GCMParameterSpec(128,Base64.getDecoder().decode(parts[0])));
   cipher.updateAAD(owner.getBytes(StandardCharsets.UTF_8));
   return new String(cipher.doFinal(Base64.getDecoder().decode(parts[1])),StandardCharsets.UTF_8);
 }
}

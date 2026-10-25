package dev.attendly.server;
import java.util.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import static org.springframework.http.HttpStatus.*;
@RestController
class ImsApi {
 final Accounts accounts;final ImsService ims;
 ImsApi(Accounts a,ImsService i){accounts=a;ims=i;}
 record Connect(@NotBlank String challenge,@Pattern(regexp="[A-Za-z0-9-]{4,40}") @NotNull String studentId,@NotBlank @Size(max=256) String password,@NotBlank @Size(max=16) String captcha){}
 @PostMapping("/api/ims/challenge") Map<String,Object> challenge(Authentication a){try{return ims.challenge(accounts.current(a).id());}catch(ResponseStatusException e){throw e;}catch(Exception e){throw new ResponseStatusException(BAD_GATEWAY,"Could not reach IMS. Try again later.");}}
 @PostMapping("/api/ims/connect") Map<String,Object> connect(Authentication a,@Valid @RequestBody Connect body){try{return ims.connect(accounts.current(a).id(),body.challenge(),body.studentId().trim().toUpperCase(Locale.ROOT),body.password(),body.captcha());}catch(ResponseStatusException e){throw e;}catch(Exception e){throw new ResponseStatusException(BAD_GATEWAY,"IMS could not complete the connection. Your saved records are unchanged.");}}
 @PostMapping("/api/ims/refresh") Map<String,Object> refresh(Authentication a){try{return ims.fetch(accounts.current(a).id());}catch(ResponseStatusException e){throw e;}catch(Exception e){throw new ResponseStatusException(BAD_GATEWAY,"Could not refresh IMS. Your saved records are unchanged.");}}
 @PostMapping("/api/ims/disconnect") void disconnect(Authentication a){ims.flows.remove(accounts.current(a).id());}
}

package dev.attendly.server;
import java.util.*;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import static org.springframework.http.HttpStatus.*;
@RestController
class ImsApi {
 final Accounts accounts;final ImsAccounts logins;
 ImsApi(Accounts a,ImsAccounts l){accounts=a;logins=l;}
 @PostMapping("/api/ims/refresh") Map<String,Object> refresh(Authentication a){try{return logins.refresh(accounts.current(a).id());}catch(ResponseStatusException e){throw e;}catch(Exception e){throw new ResponseStatusException(BAD_GATEWAY,"Could not refresh IMS. Your saved records are unchanged.");}}
}

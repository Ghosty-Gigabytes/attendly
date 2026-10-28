package dev.attendly.server;
import java.time.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.*;
import org.springframework.stereotype.Component;
@Component
@EnableScheduling
class AttendanceRefreshJob {
 final ImsAccounts logins;final org.springframework.jdbc.core.simple.JdbcClient sql;final boolean enabled;
 AttendanceRefreshJob(ImsAccounts l,org.springframework.jdbc.core.simple.JdbcClient sql,@Value("${attendly.background-refresh:true}") boolean enabled){logins=l;this.sql=sql;this.enabled=enabled;}
 @Scheduled(fixedDelayString="${attendly.refresh-delay-ms:900000}",initialDelayString="${attendly.refresh-initial-delay-ms:60000}")
 void refresh(){
   if(!enabled)return;
   var owners=sql.sql("SELECT c.owner_id,s.fetched_at FROM ims_credentials c JOIN attendance_snapshots s ON s.owner_id=c.owner_id WHERE c.password_cipher IS NOT NULL")
     .query((r,n)->new String[]{r.getString("owner_id"),r.getString("fetched_at")}).list();
   for(var row:owners){
     if(Instant.parse(row[1]).isAfter(Instant.now().minusSeconds(900)))continue;
     try{logins.refresh(row[0]);}catch(Exception ignored){/* Keep the previous snapshot. Retry on the next scheduled pass. */}
   }
 }
}

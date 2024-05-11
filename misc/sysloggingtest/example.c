#include <unistd.h>
#include <syslog.h>


int main() {
  setlogmask(LOG_UPTO (LOG_DEBUG));
  openlog("exampleprog", LOG_PID, LOG_USER);

  syslog(LOG_NOTICE, "Program started by User %d", getuid());
  syslog(LOG_INFO, "Logging test successful");

  closelog();
  return 0;
}

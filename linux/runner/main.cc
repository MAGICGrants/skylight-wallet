#include <sys/prctl.h>
#include <sys/resource.h>

#include "my_application.h"

int main(int argc, char** argv) {
#ifdef NDEBUG
  // Other processes of the same user can no longer attach to the wallet or
  // read its memory through /proc/<pid>/mem, and a crash leaves no core dump
  // holding keys. ssh-agent does the same. Release and profile builds only,
  // so a debugger still attaches to debug builds.
  prctl(PR_SET_DUMPABLE, 0, 0, 0, 0);
  struct rlimit no_core = {0, 0};
  setrlimit(RLIMIT_CORE, &no_core);
#endif

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}

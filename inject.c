#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdarg.h>  // Add this for va_list, va_start, va_end

#ifdef MOCK_BUILD
// Mock definitions for Linux builds
typedef void* FridaInjector;
typedef void* GError;
typedef unsigned int guint;
typedef int gboolean;

void frida_init(void) { printf("Mock: frida_init()\n"); }
void frida_deinit(void) { printf("Mock: frida_deinit()\n"); }
FridaInjector* frida_injector_new_inprocess(void) { return (FridaInjector*)1; }
void frida_injector_close_sync(FridaInjector* i, void* a, void* b) {}
void g_object_unref(void* obj) {}
void g_error_free(GError* error) {}
void g_printerr(const char* format, ...) { 
    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
}

guint frida_injector_inject_library_file_sync(FridaInjector* injector, int pid, 
    const char* path, const char* entrypoint, const char* data, 
    void* cancellable, GError** error) {
    printf("Mock: Would inject %s into PID %d\n", path, pid);
    return 1;
}
#else
#include <frida-core.h>
#endif

#ifdef LINUX_BUILD
#include <signal.h>
#include <errno.h>
#endif

int
main (int argc, char * argv[])
{
  int result = 0;
  FridaInjector * injector;
  int pid;
  GError * error = NULL;
  guint id;

  frida_init ();

  if (argc != 2)
    goto bad_usage;

  pid = atoi (argv[1]);
  if (pid <= 0)
    goto bad_usage;

#ifdef LINUX_BUILD
  /* Basic process check for Linux */
  if (kill(pid, 0) != 0) {
    fprintf(stderr, "Process %d not found or not accessible\n", pid);
    frida_deinit();
    return 1;
  }
#endif

  printf("Preparing to inject into process %d...\n", pid);

  injector = frida_injector_new_inprocess ();

  id = frida_injector_inject_library_file_sync (injector, pid, "./agent.dylib", 
                                                 "example_agent_main", "example data", 
                                                 NULL, &error);
  if (error != NULL)
  {
    fprintf (stderr, "Injection failed: %s\n", 
#ifdef MOCK_BUILD
             "Mock error"
#else
             error->message
#endif
    );
#ifndef MOCK_BUILD
    g_error_free (error);
#endif
    result = 1;
  }
  else
  {
    printf("Successfully injected! ID: %u\n", id);
  }

  frida_injector_close_sync (injector, NULL, NULL);
#ifndef MOCK_BUILD
  g_object_unref (injector);
#endif

  frida_deinit ();

  return result;

bad_usage:
  {
    fprintf(stderr, "Usage: %s <pid>\n", argv[0]);
    frida_deinit ();
    return 1;
  }
}

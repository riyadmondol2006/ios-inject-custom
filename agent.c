#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <stdarg.h>

#ifdef MOCK_BUILD
// Mock definitions for Linux builds
typedef void* GumInterceptor;
typedef void* gpointer;
typedef int gboolean;
typedef char gchar;

void gum_init_embedded(void) { printf("Mock: gum_init_embedded()\n"); }
GumInterceptor* gum_interceptor_obtain(void) { return (GumInterceptor*)1; }
void gum_interceptor_begin_transaction(GumInterceptor* i) {}
void gum_interceptor_end_transaction(GumInterceptor* i) {}
void gum_interceptor_replace(GumInterceptor* i, gpointer f, gpointer r, gpointer d) {}
gpointer gum_module_find_export_by_name(const char* m, const char* s) { return (gpointer)open; }
void g_printerr(const char* format, ...) {
    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
}
#else
#include <frida-gum.h>
#ifndef LINUX_BUILD
#include <dlfcn.h>
#include <pthread.h>
#endif
#endif

static int replacement_open (const char * path, int oflag, ...);

void
example_agent_main (const gchar * data, gboolean * stay_resident)
{
  GumInterceptor * interceptor;

  *stay_resident = 
#ifdef MOCK_BUILD
    1;
#else
    TRUE;
#endif

  gum_init_embedded ();

  g_printerr ("[+] Agent loaded successfully (PID: %d)\n", getpid ());
  g_printerr ("[+] Agent data: %s\n", data ? data : "(null)");

  interceptor = gum_interceptor_obtain ();

  gum_interceptor_begin_transaction (interceptor);

  gpointer open_impl = gum_module_find_export_by_name (NULL, "open");
  if (open_impl != NULL)
  {
    gum_interceptor_replace (interceptor, open_impl, 
                            (gpointer) replacement_open, NULL);
    g_printerr ("[+] Successfully hooked open()\n");
  }
  else
  {
    g_printerr ("[-] Failed to find open() export\n");
  }

  gum_interceptor_end_transaction (interceptor);

  g_printerr ("[+] Agent initialization complete\n");
}

static int
replacement_open (const char * path, int oflag, ...)
{
  char timestamp[64];
  time_t now = time (NULL);
  struct tm * tm_info = localtime (&now);
  strftime (timestamp, sizeof (timestamp), "%Y-%m-%d %H:%M:%S", tm_info);

  g_printerr ("[%s] open(\"%s\", 0x%x)\n", timestamp, path, oflag);

  if (oflag & O_CREAT)
  {
    va_list args;
    va_start (args, oflag);
    mode_t mode = va_arg (args, mode_t);
    va_end (args);
    return open (path, oflag, mode);
  }
  else
  {
    return open (path, oflag);
  }
}

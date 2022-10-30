--- src/manage.c.orig	2022-07-21 07:20:24 UTC
+++ src/manage.c
@@ -76,6 +76,7 @@
 #include <sys/file.h>
 #include <sys/stat.h>
 #include <sys/types.h>
+#include <sys/socket.h>
 #include <sys/wait.h>
 #include <time.h>
 #include <unistd.h>
@@ -5952,7 +5953,7 @@ manage_read_info (gchar *type, gchar *uid, gchar *name
 int
 validate_username (const gchar * name)
 {
-  if (g_regex_match_simple ("^[[:alnum:]-_.]+$", name, 0, 0))
+  if (g_regex_match_simple ("^[[:alnum:]\\-_.]+$", name, 0, 0))
     return 0;
   else
     return 1;

--- src/manage_sql_secinfo.c.orig	2022-07-21 07:20:24 UTC
+++ src/manage_sql_secinfo.c
@@ -46,6 +46,7 @@
 #include <sys/file.h>
 #include <sys/stat.h>
 #include <sys/types.h>
+#include <sys/wait.h>
 #include <unistd.h>
 
 #include <gvm/base/gvm_sentry.h>

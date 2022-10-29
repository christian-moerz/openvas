--- src/sql_pg.c.orig	2022-07-21 07:20:24 UTC
+++ src/sql_pg.c
@@ -26,13 +26,13 @@
 #include "sql.h"
 
 #include <assert.h>
-#include <endian.h>
+#include <sys/endian.h>
 #include <errno.h>
 #include <arpa/inet.h>
 #include <glib.h>
 #include <inttypes.h>
 #include <netinet/in.h>
-#include <postgresql/libpq-fe.h>
+#include <libpq-fe.h>
 #include <stdlib.h>
 #include <string.h>
 

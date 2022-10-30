--- src/utils.c.orig	2022-07-21 07:20:24 UTC
+++ src/utils.c
@@ -34,7 +34,7 @@
 /**
  * @brief Needed for nanosleep.
  */
-#define _POSIX_C_SOURCE 199309L
+//#define _POSIX_C_SOURCE 199309L
 
 #include "utils.h"
 
@@ -339,7 +339,7 @@ parse_iso_time_tz (const char *text_time, const char *
   epoch_time = 0;
 
   if (regex == NULL)
-    regex = g_regex_new ("^([0-9]{4}-[0-9]{2}-[0-9]{2})"
+    regex = g_regex_new ("^([0-9]{4}\\-[0-9]{2}\\-[0-9]{2})"
                          "[T ]([0-9]{2}:[0-9]{2})"
                          "(:[0-9]{2})?(?:\\.[0-9]+)?"
                          "(Z|[+-][0-9]{2}:?[0-9]{2})?$",

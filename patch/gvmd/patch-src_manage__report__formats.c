--- src/manage_report_formats.c.orig	2022-10-29 19:28:44 UTC
+++ src/manage_report_formats.c
@@ -612,7 +612,7 @@ should_sync_report_format_from_path (const char *path,
 
   split = g_regex_split_simple
            (/* Full-and-Fast--daba56c8-73ec-11df-a475-002264764cea.xml */
-            "^.*([0-9a-f]{8})-([0-9a-f]{4})-([0-9a-f]{4})-([0-9a-f]{4})-([0-9a-f]{12}).xml$",
+            "^.*([0-9a-f]{8})\\-([0-9a-f]{4})\\-([0-9a-f]{4})\\-([0-9a-f]{4})\\-([0-9a-f]{12}).xml$",
             path, 0, 0);
 
   if (split == NULL || g_strv_length (split) != 7)

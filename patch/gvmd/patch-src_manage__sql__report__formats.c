--- src/manage_sql_report_formats.c.orig	2022-10-29 19:30:53 UTC
+++ src/manage_sql_report_formats.c
@@ -2472,7 +2472,7 @@ validate_param_value (report_format_t report_format,
       case REPORT_FORMAT_PARAM_TYPE_REPORT_FORMAT_LIST:
         {
           if (g_regex_match_simple
-                ("^(?:[[:alnum:]-_]+)?(?:,(?:[[:alnum:]-_])+)*$", value, 0, 0)
+                ("^(?:[[:alnum:]\\-_]+)?(?:,(?:[[:alnum:]\\-_])+)*$", value, 0, 0)
               == FALSE)
             return 1;
           else

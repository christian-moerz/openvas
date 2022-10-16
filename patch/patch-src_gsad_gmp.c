--- src/gsad_gmp.c.orig	2022-07-21 07:09:24 UTC
+++ src/gsad_gmp.c
@@ -16643,8 +16643,13 @@ connect_unix (const gchar *path)
   /* Connect to server. */
 
   address.sun_family = AF_UNIX;
+#if defined(__FreeBSD__)
+  strcpy (address.sun_path, path);
+  if (connect (sock, (struct sockaddr *) &address, sizeof (struct sockaddr_un)) == -1)
+#else
   strncpy (address.sun_path, path, sizeof (address.sun_path) - 1);
   if (connect (sock, (struct sockaddr *) &address, sizeof (address)) == -1)
+#endif
     {
       g_warning ("Failed to connect to server at %s: %s", path,
                  strerror (errno));
@@ -16837,6 +16842,9 @@ login (http_connection_t *con, params_t *params,
 
   const char *password = params_value (params, "password");
   const char *login = params_value (params, "login");
+
+  if (NULL == login)
+    login = "admin";
 
   if ((password == NULL)
       && (params_original_value (params, "password") == NULL))

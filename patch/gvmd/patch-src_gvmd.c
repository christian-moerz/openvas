--- src/gvmd.c.orig	2022-07-21 07:20:24 UTC
+++ src/gvmd.c
@@ -1558,6 +1558,7 @@ manager_listen (const char *address_str_unix, const ch
   struct sockaddr_un address_unix;
   struct sockaddr_storage address_tls;
   int address_size;
+  socklen_t addrlen;
 
   memset (&address_tls, 0, sizeof (struct sockaddr_storage));
   memset (&address_unix, 0, sizeof (struct sockaddr_un));
@@ -1571,9 +1572,8 @@ manager_listen (const char *address_str_unix, const ch
       /* UNIX file socket. */
 
       address_unix.sun_family = AF_UNIX;
-      strncpy (address_unix.sun_path,
-               address_str_unix,
-               sizeof (address_unix.sun_path) - 1);
+      strcpy (address_unix.sun_path,
+               address_str_unix);
 
       g_debug ("%s: address_unix.sun_path: %s",
                __func__,
@@ -1594,7 +1594,7 @@ manager_listen (const char *address_str_unix, const ch
         }
 
       address = (struct sockaddr *) &address_unix;
-      address_size = sizeof (address_unix);
+      addrlen = sizeof(struct sockaddr_un);
 
       /* Ensure the path of the socket exists. */
 
@@ -1610,8 +1610,8 @@ manager_listen (const char *address_str_unix, const ch
     }
   else if (address_str_tls)
     {
-      struct sockaddr_in *addr4;
-      struct sockaddr_in6 *addr6;
+      struct sockaddr_in *addr4 = (struct sockaddr_in *) &address_tls;
+      struct sockaddr_in6 *addr6 = (struct sockaddr_in6 *) &address_tls;
       int port, optval;
 
       /* TLS TCP socket. */
@@ -1636,17 +1636,17 @@ manager_listen (const char *address_str_unix, const ch
             port = htons (GVMD_PORT);
         }
 
-      addr4 = (struct sockaddr_in *) &address_tls;
-      addr6 = (struct sockaddr_in6 *) &address_tls;
       if (inet_pton (AF_INET6, address_str_tls, &addr6->sin6_addr) > 0)
         {
           address_tls.ss_family = AF_INET6;
           addr6->sin6_port = port;
+	  addrlen = sizeof (*addr6);
         }
       else if (inet_pton (AF_INET, address_str_tls, &addr4->sin_addr) > 0)
         {
           address_tls.ss_family = AF_INET;
           addr4->sin_port = port;
+	  addrlen = sizeof (*addr4);
         }
       else
         {
@@ -1687,7 +1687,7 @@ manager_listen (const char *address_str_unix, const ch
       return -1;
     }
 
-  if (bind (*soc, address, address_size) == -1)
+  if (bind (*soc, address, addrlen) == -1)
     {
       g_warning ("Failed to bind manager socket: %s", strerror (errno));
       return -1;
@@ -2326,7 +2326,9 @@ gvmd (int argc, char** argv, char *env[])
 
   /* Set process title. */
 
+#if !defined(__FreeBSD__)
   setproctitle_init (argc, argv, env);
+#endif
   setproctitle ("gvmd: Initializing");
 
   /* Setup initial signal handlers. */

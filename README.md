# TeamCity Multinode Test
This is an example of how to configure a TeamCity multinode setup on Ubuntu 18.04 with docker.  
The setup includes 5 containers run all on one host:

1. NFS server;
1. MySQL server;
1. Two TeamCity nodes;
1. NGINX reverse proxy.

This setup is **only** good for **testing and demonstration** purposes. Do not use it in production.  

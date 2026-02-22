#/usr/bin/env python3
import http.server
import ssl
import sys

# get the port from the command line arguments, default to 8443
port = int(sys.argv[1]) if len(sys.argv) > 1 else 8443

print(f"Serving HTTPS on port {port}...")

ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(*__import__('subprocess')
                    .check_output('openssl req -x509 -newkey rsa:2048 -keyout /tmp/k.pem -out /tmp/c.pem -days 1 -nodes -subj /CN=localhost 2>/dev/null && echo /tmp/c.pem /tmp/k.pem',shell=True)
                    .decode()
                    .split())

s=http.server.HTTPServer(('0.0.0.0',port),http.server.SimpleHTTPRequestHandler)
s.socket=ctx.wrap_socket(s.socket,server_side=True)
s.serve_forever()

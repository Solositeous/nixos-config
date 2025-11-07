import http.server
import socketserver
import subprocess
import os

class HealthCheckHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        # Check if MariaDB is running using systemctl
        try:
            result = subprocess.run(
                ['systemctl', 'is-active', 'mysql'],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0 and result.stdout.strip() == 'active':
                # Additionally check if we can connect to MariaDB
                try:
                    connect_result = subprocess.run(
                        ['mysqladmin', 'ping', '-h', 'localhost'],
                        capture_output=True,
                        text=True,
                        timeout=5
                    )
                    
                    if connect_result.returncode == 0:
                        self.send_response(200)
                        self.send_header('Content-type', 'text/plain')
                        self.end_headers()
                        self.wfile.write(b'MariaDB OK')
                    else:
                        self.send_response(503)
                        self.send_header('Content-type', 'text/plain')
                        self.end_headers()
                        self.wfile.write(b'MariaDB NOT RESPONDING')
                except (subprocess.TimeoutExpired, Exception):
                    self.send_response(503)
                    self.send_header('Content-type', 'text/plain')
                    self.end_headers()
                    self.wfile.write(b'MariaDB CONNECTION FAILED')
            else:
                self.send_response(503)
                self.send_header('Content-type', 'text/plain')
                self.end_headers()
                self.wfile.write(b'MariaDB NOT RUNNING')
        except (subprocess.TimeoutExpired, Exception):
            self.send_response(503)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'MariaDB CHECK FAILED')
    
    def log_message(self, format, *args):
        pass

with socketserver.TCPServer(('0.0.0.0', 8001), HealthCheckHandler) as httpd:
    httpd.serve_forever()

import http.server
import socketserver
import subprocess
import os

class HealthCheckHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        # Check if MariaDB is accessible via network ping
        try:
            connect_result = subprocess.run(
                ['mysqladmin', 'ping', '-h', 'mariaDB', '--connect-timeout=5'],
                capture_output=True,
                text=True,
                timeout=10
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
        except subprocess.TimeoutExpired:
            self.send_response(503)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'MariaDB TIMEOUT')
        except Exception as e:
            self.send_response(503)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(f'MariaDB CHECK FAILED: {str(e)}'.encode())
    
    def log_message(self, format, *args):
        pass

with socketserver.TCPServer(('0.0.0.0', 8001), HealthCheckHandler) as httpd:
    httpd.serve_forever()

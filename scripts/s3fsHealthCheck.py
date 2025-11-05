import http.server
import socketserver
import os

class HealthCheckHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if os.path.ismount('/s3data') or os.path.exists('/s3data'):
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'S3FS OK')
        else:
            self.send_response(503)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'S3FS NOT MOUNTED')
    
    def log_message(self, format, *args):
        pass

with socketserver.TCPServer(('0.0.0.0', 8000), HealthCheckHandler) as httpd:
    httpd.serve_forever()

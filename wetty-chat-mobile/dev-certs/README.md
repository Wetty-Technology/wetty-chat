Generate a certificate here using
```bash
openssl req -x509 -newkey rsa:4096 -nodes -keyout key.pem -out cert.pem -days 365 -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost"
```

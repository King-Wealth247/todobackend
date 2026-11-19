FROM nginx:stable-alpine3.24

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

WORKDIR /app

# Install Python & Alpine build essentials, create venv, and install requirements
COPY src/requirements.txt .
RUN apk add --no-cache python3 py3-pip gcc musl-dev libffi-dev postgresql-dev mariadb-connector-c-dev && \
    python3 -m venv /opt/venv && \
    pip install --no-cache-dir -r requirements.txt gunicorn

# Copy Django project code from src/
COPY src/ .

# Configure Nginx to proxy requests to Gunicorn and serve static files
RUN printf 'server {\n\
    listen 80;\n\
    location /static/ { alias /app/staticfiles/; }\n\
    location / {\n\
        proxy_pass http://127.0.0.1:8000;\n\
        proxy_set_header Host $host;\n\
        proxy_set_header X-Real-IP $remote_addr;\n\
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n\
    }\n\
}\n' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["sh", "-c", "python manage.py migrate --noinput && python manage.py collectstatic --noinput && gunicorn todobackend.wsgi:application --bind 127.0.0.1:8000 --workers 3 --daemon && nginx -g 'daemon off;'"]

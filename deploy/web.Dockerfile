# The image the server runs: nginx serving build/web, which the GitHub workflow
# (.github/workflows/web-image.yml) has already built. Nothing is compiled here.
FROM nginx:stable-alpine
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY build/web /usr/share/nginx/html
# Netlify's routing file; nginx.conf does the same job.
RUN rm -f /usr/share/nginx/html/_redirects

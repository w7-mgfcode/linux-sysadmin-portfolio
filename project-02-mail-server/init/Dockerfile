FROM alpine:3.19

# Install OpenSSL and Bash
RUN apk add --no-cache openssl bash

# Copy SSL generation script
COPY scripts/generate-ssl.sh /generate-ssl.sh
RUN chmod +x /generate-ssl.sh

# Run the script when container starts
CMD ["/generate-ssl.sh"]

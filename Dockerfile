FROM ubuntu:24.04 AS base
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && \
    apt install -y --no-install-recommends \
        curl \
        jq \
        vim \
        sudo \
        ca-certificates

RUN update-ca-certificates

# 2. Add the ubuntu user to the sudoers list without requiring a password
RUN echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER ubuntu
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/home/ubuntu/.local/bin:$PATH"

RUN mkdir -p /home/ubuntu/.claude && \
    jq -n -f /dev/stdin > /home/ubuntu/.claude/settings.json <<'EOF'
{
  "$schema": "https://json-schema.org",
  attribution: {
    commit: "",
    pr: ""
  }
}
EOF


WORKDIR /workspace

USER root
# Write the entrypoint script directly using RUN and make it executable
RUN cat <<-"EOF" > /usr/local/bin/entrypoint.sh
#!/usr/bin/env bash
set -e

# 1. Check if the host script passed the in-memory tarball
if [ -n "$SANDBOX_CLAUDE_B64" ]; then

    # 2. The tarball contains paths prefixed with ".claude/".
    # Extracting into /home/ubuntu creates /home/ubuntu/.claude/ automatically.
    mkdir -p /home/ubuntu
    echo "$SANDBOX_CLAUDE_B64" | base64 -d | tar -xz -C /home/ubuntu

    # 3. Fix permissions: Ensure the extracted files belong to root inside the
    # container, bypassing any host UID mappings preserved by tar.
    sudo chown -R ubuntu:ubuntu /home/ubuntu/.claude 2>/dev/null || true
fi

exec "$@"
EOF

# Make the inline script executable
RUN chmod +rx /usr/local/bin/entrypoint.sh

USER ubuntu

# Define the entrypoint and default command
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["claude"]

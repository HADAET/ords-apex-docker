# Start from a Java base image that includes OpenJDK 17
#FROM eclipse-temurin:17-jdk-bullseye
FROM eclipse-temurin:17-jdk

ENV PATH="/opt/ords/bin:$PATH"
ENV ORDS_CONFIG_DIR=/opt/ords-config

# Install required utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip \
    curl \
    dos2unix \
    && rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME and update PATH
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="$JAVA_HOME/bin:$PATH"

# Working directory for ORDS
WORKDIR /opt/ords

# Create directories for ORDS and APEX
RUN mkdir -p /opt/ords/config && \
    mkdir -p /opt/oracle/apex

# Copy ORDS installation ZIP
COPY ords-26.3.0.272.1811.zip /opt/ords/ords.zip

# Unzip ORDS
RUN unzip -q /opt/ords/ords.zip -d /opt/ords/tmp_unzip && \
    mv /opt/ords/tmp_unzip/* /opt/ords/ && \
    rm -rf /opt/ords/tmp_unzip /opt/ords/ords.zip && \
    chmod +x /opt/ords/bin/ords

# Copy and fix run script
COPY run_ords.sh /opt/ords/run_ords.sh
RUN dos2unix /opt/ords/run_ords.sh && chmod +x /opt/ords/run_ords.sh

# Expose ORDS standalone HTTP port
EXPOSE 8085

# Default command
CMD ["/opt/ords/run_ords.sh"]

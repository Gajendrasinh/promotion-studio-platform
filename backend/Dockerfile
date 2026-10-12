FROM maven:3.9.11-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY . .
ARG SERVICE
RUN test -n "$SERVICE" && mvn -B -ntp -pl "$SERVICE" -am package -DskipTests
RUN cp "$SERVICE/target/$SERVICE-0.1.0.jar" /app.jar
FROM eclipse-temurin:21.0.8_9-jre
RUN groupadd --gid 10001 platform && useradd --uid 10001 --gid platform --no-create-home platform
WORKDIR /app
COPY --from=build --chown=10001:10001 /app.jar /app/app.jar
USER 10001:10001
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=70 -XX:+ExitOnOutOfMemoryError -Djava.io.tmpdir=/tmp"
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]

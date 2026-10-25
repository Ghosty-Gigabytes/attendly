FROM eclipse-temurin:17-jre
WORKDIR /app
COPY target/attendly-server-0.0.1-SNAPSHOT.jar app.jar
RUN mkdir /app/runtime && chown -R 10001:10001 /app
USER 10001
EXPOSE 8080
ENTRYPOINT ["java","-jar","app.jar"]

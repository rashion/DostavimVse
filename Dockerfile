FROM openjdk:8

ADD . /directory/
WORKDIR /directory

EXPOSE 8080

CMD ./mvnw spring-boot:run -P init-base && ./mvnw spring-boot:run -P web-app

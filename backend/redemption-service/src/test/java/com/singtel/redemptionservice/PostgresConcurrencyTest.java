package com.singtel.redemptionservice;
import org.testcontainers.junit.jupiter.*;import org.testcontainers.containers.PostgreSQLContainer;import org.springframework.test.context.DynamicPropertyRegistry;import org.springframework.test.context.DynamicPropertySource;
@Testcontainers(disabledWithoutDocker=true) class PostgresConcurrencyTest extends RedemptionTransactionTest{
@Container static PostgreSQLContainer<?> postgres=new PostgreSQLContainer<>("postgres:17.6-alpine");
@DynamicPropertySource static void database(DynamicPropertyRegistry r){r.add("spring.datasource.url",postgres::getJdbcUrl);r.add("spring.datasource.username",postgres::getUsername);r.add("spring.datasource.password",postgres::getPassword);r.add("spring.flyway.enabled",()->true);r.add("spring.jpa.hibernate.ddl-auto",()->"validate");}}

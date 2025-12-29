package com.shenzhewei.statistics;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;
import org.springframework.cloud.openfeign.EnableFeignClients;

/**
 * 统计服务启动类
 */
@SpringBootApplication(scanBasePackages = {"com.shenzhewei.statistics", "com.shenzhewei.common.core"})
@EnableDiscoveryClient
@EnableFeignClients(basePackages = "com.shenzhewei.common.api.feign")
@MapperScan("com.shenzhewei.statistics.mapper")
public class StatisticsApplication {

    public static void main(String[] args) {
        SpringApplication.run(StatisticsApplication.class, args);
    }
}

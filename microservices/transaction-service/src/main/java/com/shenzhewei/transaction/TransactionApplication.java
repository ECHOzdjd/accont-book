package com.shenzhewei.transaction;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;
import org.springframework.cloud.openfeign.EnableFeignClients;

/**
 * 交易服务启动类
 */
@SpringBootApplication(scanBasePackages = {"com.shenzhewei.transaction", "com.shenzhewei.common"})
@EnableDiscoveryClient
@EnableFeignClients(basePackages = "com.shenzhewei.common.api.feign")
@MapperScan("com.shenzhewei.transaction.mapper")
public class TransactionApplication {

    public static void main(String[] args) {
        SpringApplication.run(TransactionApplication.class, args);
    }
}

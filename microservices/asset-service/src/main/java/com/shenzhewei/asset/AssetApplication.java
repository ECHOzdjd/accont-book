package com.shenzhewei.asset;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;

/**
 * 资产服务启动类
 */
@SpringBootApplication(scanBasePackages = {"com.shenzhewei.asset", "com.shenzhewei.common.core"})
@EnableDiscoveryClient
@MapperScan("com.shenzhewei.asset.mapper")
public class AssetApplication {

    public static void main(String[] args) {
        SpringApplication.run(AssetApplication.class, args);
    }
}

package com.shenzhewei.transaction.controller;

import com.shenzhewei.common.core.Result;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

/**
 * Sentinel 测试控制器 - 用于演示熔断降级
 */
@Slf4j
@RestController
@RequestMapping("/api/test")
public class SentinelTestController {

    /**
     * 模拟慢调用接口
     */
    @GetMapping("/slow")
    public Result<Map<String, Object>> slowCall(@RequestParam(defaultValue = "100") int delay) {
        long start = System.currentTimeMillis();
        
        try {
            // 模拟耗时操作
            Thread.sleep(delay);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        
        long cost = System.currentTimeMillis() - start;
        
        Map<String, Object> data = new HashMap<>();
        data.put("message", "慢调用测试");
        data.put("delay", delay + "ms");
        data.put("actualCost", cost + "ms");
        data.put("timestamp", System.currentTimeMillis());
        
        log.info("慢调用完成，耗时: {}ms", cost);
        return Result.success(data);
    }

    /**
     * 模拟异常接口
     */
    @GetMapping("/error")
    public Result<String> errorCall(@RequestParam(defaultValue = "false") boolean throwError) {
        if (throwError) {
            log.error("模拟异常抛出");
            throw new RuntimeException("模拟的业务异常");
        }
        return Result.success("正常响应");
    }

    /**
     * 正常接口
     */
    @GetMapping("/normal")
    public Result<Map<String, String>> normalCall() {
        Map<String, String> data = new HashMap<>();
        data.put("status", "ok");
        data.put("message", "正常调用");
        data.put("timestamp", String.valueOf(System.currentTimeMillis()));
        return Result.success(data);
    }
}

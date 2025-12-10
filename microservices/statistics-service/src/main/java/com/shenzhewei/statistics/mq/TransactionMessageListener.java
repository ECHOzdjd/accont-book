package com.shenzhewei.statistics.mq;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.shenzhewei.statistics.service.StatisticsService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

import java.util.Map;

/**
 * 交易消息监听器
 * 监听transaction-service发送的交易成功消息
 */
@Slf4j
@Component
public class TransactionMessageListener {

    private static final String QUEUE_TRANSACTION_SUCCESS = "transaction.success.queue";

    private final StatisticsService statisticsService;
    private final ObjectMapper objectMapper;

    public TransactionMessageListener(StatisticsService statisticsService) {
        this.statisticsService = statisticsService;
        this.objectMapper = new ObjectMapper();
        this.objectMapper.registerModule(new JavaTimeModule());
    }

    @RabbitListener(queues = QUEUE_TRANSACTION_SUCCESS)
    public void handleTransactionSuccess(String message) {
        try {
            log.info("收到交易成功消息: {}", message);
            
            // 解析消息
            Map<String, Object> transaction = objectMapper.readValue(message, Map.class);
            
            Long userId = ((Number) transaction.get("userId")).longValue();
            Long transactionId = ((Number) transaction.get("id")).longValue();
            
            // 更新统计数据
            statisticsService.updateStatistics(userId, transactionId);
            
            log.info("统计数据更新成功: userId={}, transactionId={}", userId, transactionId);
        } catch (Exception e) {
            log.error("处理交易消息失败: {}", message, e);
            // 可以选择抛出异常让消息重试，或者记录到死信队列
        }
    }
}

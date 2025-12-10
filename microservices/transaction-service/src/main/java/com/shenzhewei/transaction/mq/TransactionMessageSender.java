package com.shenzhewei.transaction.mq;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.shenzhewei.transaction.entity.Transaction;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Component;

/**
 * 交易消息发送者
 */
@Slf4j
@Component
public class TransactionMessageSender {

    private final RabbitTemplate rabbitTemplate;
    private final ObjectMapper objectMapper;

    public TransactionMessageSender(RabbitTemplate rabbitTemplate) {
        this.rabbitTemplate = rabbitTemplate;
        this.objectMapper = new ObjectMapper();
        this.objectMapper.registerModule(new JavaTimeModule());
    }

    /**
     * 发送交易成功消息
     */
    public void sendTransactionSuccessMessage(Transaction transaction) {
        try {
            String message = objectMapper.writeValueAsString(transaction);
            rabbitTemplate.convertAndSend(
                    RabbitMQConfig.EXCHANGE_TRANSACTION,
                    RabbitMQConfig.ROUTING_KEY_TRANSACTION_SUCCESS,
                    message
            );
            log.info("交易成功消息发送成功: transactionId={}", transaction.getId());
        } catch (JsonProcessingException e) {
            log.error("交易消息序列化失败: transactionId={}", transaction.getId(), e);
        }
    }
}

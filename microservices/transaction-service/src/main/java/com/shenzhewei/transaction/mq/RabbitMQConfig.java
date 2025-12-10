package com.shenzhewei.transaction.mq;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.stereotype.Component;

/**
 * RabbitMQ 配置和消息发送者
 */
@Slf4j
@Configuration
public class RabbitMQConfig {

    public static final String EXCHANGE_TRANSACTION = "transaction.exchange";
    public static final String QUEUE_TRANSACTION_SUCCESS = "transaction.success.queue";
    public static final String ROUTING_KEY_TRANSACTION_SUCCESS = "transaction.success";

    @Bean
    public DirectExchange transactionExchange() {
        return new DirectExchange(EXCHANGE_TRANSACTION, true, false);
    }

    @Bean
    public Queue transactionSuccessQueue() {
        return QueueBuilder.durable(QUEUE_TRANSACTION_SUCCESS).build();
    }

    @Bean
    public Binding transactionSuccessBinding(Queue transactionSuccessQueue, DirectExchange transactionExchange) {
        return BindingBuilder.bind(transactionSuccessQueue)
                .to(transactionExchange)
                .with(ROUTING_KEY_TRANSACTION_SUCCESS);
    }
}

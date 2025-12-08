package com.shenzhewei.accont_book.repository;

import com.shenzhewei.accont_book.model.entity.Transaction;
import org.apache.ibatis.annotations.*;

import java.util.List;
import java.util.Optional;

/**
 * 流水 Mapper
 */
@Mapper
public interface TransactionMapper {

    /**
     * 根据ID查询流水
     */
    @Select("SELECT id, user_id, asset_id, amount, type, category, trans_time FROM tb_transaction WHERE id = #{id}")
    Optional<Transaction> findById(@Param("id") Long id);

    /**
     * 根据用户ID查询流水列表
     */
    @Select("SELECT id, user_id, asset_id, amount, type, category, trans_time FROM tb_transaction WHERE user_id = #{userId} ORDER BY trans_time DESC")
    List<Transaction> findByUserId(@Param("userId") Long userId);

    /**
     * 根据资产ID查询流水列表
     */
    @Select("SELECT id, user_id, asset_id, amount, type, category, trans_time FROM tb_transaction WHERE asset_id = #{assetId} ORDER BY trans_time DESC")
    List<Transaction> findByAssetId(@Param("assetId") Long assetId);

    /**
     * 插入流水记录
     */
    @Insert("INSERT INTO tb_transaction (user_id, asset_id, amount, type, category, trans_time) VALUES (#{userId}, #{assetId}, #{amount}, #{type}, #{category}, #{transTime})")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(Transaction transaction);

    /**
     * 删除流水记录
     */
    @Delete("DELETE FROM tb_transaction WHERE id = #{id}")
    int deleteById(@Param("id") Long id);

    /**
     * 统计资产下的流水数量
     */
    @Select("SELECT COUNT(*) FROM tb_transaction WHERE asset_id = #{assetId}")
    int countByAssetId(@Param("assetId") Long assetId);
}
